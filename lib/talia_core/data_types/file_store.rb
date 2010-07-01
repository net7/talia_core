require 'fileutils'

module TaliaCore
  module DataTypes
    
    # The "hevy lifting" for FileRecords, handling the actual creation and
    # manipulation of the files. 
    #
    # A record can be created with create_from_file (passing a filename) or 
    # with create_from_data, passing a byte array.
    #
    # While a "location" can be passed to the record (which will be save 
    # in the database), the actual file name will be determined by the system.
    # Also see the PathHelpers for info
    #
    # The base directory for file storage can be configured in the 
    # talia_core.yml file as "data_directory_location". Otherwise,
    # RAILS_ROOT/data. Inside, each record will be stored at 
    # "<data class of the record>/<last three numbers of the id>/<record id>"
    # 
    # So, for example, a "XmlData" record with the id "123456" would be stored
    # as "DATA_ROOT/XmlData/456/123456"
    #
    # = Creating new records
    #
    # When creating a new record using create_from_data, the data will be cached
    # inside the object and only be saved when the record itself is saved. In 
    # this case, the file data is simply written to file during the save operation.
    #
    # When the record is created using create_from_file, the behaviour depens on
    # the parameters passed and the system settings.
    #
    # * In case the delete_original flag is set, the system will try to move the
    #   file to the new location. If both are on the same file system, this will
    #   be quicker than a copy operation.
    # * Currently, the move operation uses the "mv" command. This is does not work
    #   on windows, but is a workaround to stability problems with the file handling
    #   in JRuby
    # * If the delete_original flag is not set, the system will attempt to copy the
    #   files:
    #   * If the "delay_file_copies" options is set in the _environment_, no copy
    #     operation will be done. Instead, the system will create a "delayed_copies.sh"
    #     script that can be executed from a UNIX shell to do the actual copying.
    #     This is extremely fast and stable, as no actual copying is done.
    #   * Otherwise Talia will attempt to copy the file by itself. If the "fast_copies"
    #     flag is set in _environment_, it will use the internal copy routine
    #     which will work on any system. Otherwise, it will call the system's "cp"
    #     command, which can sometimes be more stable with jruby.
    #
    # Also see the DataLoader module to see how the creation of records automatically
    # selects the record type and loader, depending on the MIME type of the data.
    #
    # *Note*: The above behaviour means that for files that are treated through "copy"
    # or "move", the original file must not be touched by external processes until
    # the record is saved
    module FileStore
  
      # The file handle of the current record
      @file_handle = nil
      # Read cursor within the current record
      @position    = 0      
   
      # Class used to represent data paths in file records. This type is used for
      # strings that contain a path to a file, to distinguish them from "normal"
      # string, which may contain plain data.
      class DataPath < String ; end
      
      module ClassMethods
      
        # Does a #find_and_create_by_location_and_source_id - meaning that if a record
        # with given location already exists on the given source, the existing record
        # will be returned. Otherwise a new record will be created.
        #
        # In any case, the given file will be attached using #file= 
        #
        # *Options*:
        #
        # [*file*] Filename for the file to be attached - will also be used to generate
        #          the location
        # [*source_id*] Id (or uri) of the source that the record should be attached to
        def find_or_create_and_assign_file(params)
          data_record = self.find_or_create_by_location_and_source_id(params[:file].try(:original_filename), params[:source_id])
          data_record.file = params[:file]
          data_record.save # force attachment save and it also saves type attribute.
        end
      
      end
    
      # Creates a new record from an existing file on the file system.
      # The file will be copied or moved when the new record is saved - see
      # the module documentation to see how this works in detail.
      def create_from_file(location, file_path, delete_original = false)
        close_file
        self.location = location
        @file_data_to_write = DataPath.new(file_path)
        @delete_original_file = delete_original
      end
  
      # Creates a new record from the given data (binary array). See
      # the module documentation for the details; the data will be cached
      # and written to disk once the new record is saved.
      def create_from_data(location, data, options = {})
        # close file if opened
        close_file
    
        # Set the location for the record
        self.location = location
    
        if(data.respond_to?(:read))
          @file_data_to_write = data.read
        else
          @file_data_to_write = data
        end
    
      end
      
      # Returns the contents of the file as a text string.
      def all_text
        if(!is_file_open?)
          open_file
        end
        @file_handle.read(self.size)
      end
  
      # This is a placeholder in case file is used in a form.
      def file() nil; end
    
      # Assign the file data (<tt>StringIO</tt> or <tt>File</tt>).
      #
      # *Note*: At the moment this method is _different_ internally to 
      # the create_* methods, and it should be avoided using them together.
      def file=(file_data)
        return nil if file_data.nil? || file_data.size == 0 
        self.assign_type file_data.content_type
        self.location = file_data.original_filename
        if file_data.is_a?(StringIO)
          file_data.rewind
          self.temp_data = file_data.read
        else
          self.temp_path = file_data.path
        end
        @save_attachment = true
      end
    
      # Callback for writing the data from create_from_data or create_from_file. If there is
      # a problem saving this file, only an internal assertion is thrown so that it won't crash
      # production environments.
      def write_file_after_save 
        # check if there are data to write
        return unless(@file_data_to_write)
    
        begin
          self.class.benchmark("\033[36m\033[1m\033[4mFileStore\033[0m Saving file for #{self.id}") do
            # create data directory path
            FileUtils.mkdir_p(data_directory)
    
            if(@file_data_to_write.is_a?(DataPath))
              copy_data_file
            else
              save_cached_data
            end
          
            @file_data_to_write = nil
          end
        rescue Exception => e
          assit_fail("Exception on writing file #{self.location}: #{e}")
        end

      end
   
      # Return true if the data file is open
      def is_file_open?
        (@file_handle != nil)
      end
       
      
      # Assign the STI subclass, perfoming a mime-type lookup.
      def assign_type(content_type)
        self.type = MimeMapping.class_type_from(content_type).name
      end
      
      private
      
      # This saves the cached data from create_from_data. Simply writes the
      # data to disk.
      def save_cached_data
        # open file for writing
        @file_handle = File.open(file_path, 'w')
      
        # write data string into file
        @file_handle << (@file_data_to_write.respond_to?(:read) ? @file_data_to_write.read : @file_data_to_write)
    
        # close file
        close_file
    
      end
      
      # This copies the data file with which this object was created to the
      # actual storage lcoation. This is for records created with create_from_file
      def copy_data_file
        copy_or_move(@file_data_to_write, file_path)
      end
      
      # Open a specified file name and return a file handle.
      # If the file is already opened, return the file handle
      def open_file(file_name = file_path, options = 'rb')
        # chek if the file name really exists, otherwise raise an exception
        if !File.exists?(file_name)
          raise(IOError, "File #{file_name} could not be opened.", caller)
        end
    
        # try to open the specified file if is not already open
        if @file_handle == nil
          @file_handle = File.open(file_name, options)
      
          # check and set the initial position of the reading cursors.
          # It's necessary to do this thing because we don't know if the user
          # has specified the initial reading cursors befort starting working on file
          @position ||= @file_handle.pos
      
          @file_handle.pos = @position
        end
      end

      # Close an already opened file
      def close_file
        if is_file_open?
          @file_handle.close
      
          # reset 'flags' variables and position
          @file_handle = nil
          @position    = 0
        end
      end

      # Read all bytes from the file  
      def read_all_bytes
        # 1. Open file with option "r" (reading) and "b" (binary, useful for window system)
        open_file
      
        # 2. Read all bytes
        begin
          bytes = @file_handle.read(self.size).unpack("C*")
          return bytes
        rescue
          # re-raise system the excepiton
          raise
          return nil
        ensure
          # 3. Close the file
          close_file
        end
      end

      # Gets the next byte of the file
      def next_byte(close)
        if !is_file_open?
          open_file
        end
    
        begin
          current_byte = @file_handle.getc
      
          if current_byte == nil or close
            close_file
          else
            @position += 1
          end

          return current_byte
        rescue
          # re-raise system the excepiton
          raise
          close_file
          return nil
        end
    
      end

      # Copy or move the source file to the target depending on the 
      # <tt>delete_original</tt> setting in #create_from_file. 
      # Working around all the
      # things that suck in JRuby. This will honour two environment settings:
      # 
      # * delay_file_copies - will not copy the files, but create a batch file
      #     so that the copy can be done later. Uses the DelayedCopier class.
      # * fast_copies - will use the "normal" copy method from FileUtils that
      #     is faster. Since it crashed the system for us, the default is to
      #     use a "safe" workaround. The workaround is probably necessary for
      #     JRuby only.
      def copy_or_move(original, target)
        if(@delete_original_file)
          #FIXME: this doesn't work in linux
          #   FileUtils.move(original, target)
          # we have to use the system call as a workaround
          from_file = File.expand_path(original)
          to_file = File.expand_path(target)
          system_success = system("mv '#{from_file}' '#{to_file}'")
          raise(IOError, "move error '#{from_file}' '#{to_file}'") unless system_success
        else
          # Delay can be enabled through enviroment
          if(delay_copies)
            DelayedCopier.cp(original, target)
          elsif(fast_copies)
            FileUtils.copy(original, target)
          else
            # Call the copy as an external command. This is to work around the
            # crashes that occurred using the builtin copy
            from_file = File.expand_path(original)
            to_file = File.expand_path(target)
            system_success = system("cp '#{from_file}' '#{to_file}'")
            raise(IOError, "copy error '#{from_file}' '#{to_file}'") unless system_success
          end
        end
      end
      
      
      # Returns true if the 'delay_file_copies' option is set in the environment
      def delay_copies
        ENV['delay_file_copies'] == 'true' || ENV['delay_file_copies'] == 'yes'
      end
        
      # Returns true if the 'fast_copies' option is enabled in the environment.
      # Otherwise the class will use a workaround that is less likely to 
      # crash the whole system using JRuby.
      def fast_copies
        ENV['fast_copies'] == 'true' || ENV['fast_copies'] == 'yes'
      end
      
      # Return the data size
      def data_size
        File.size(file_path)
      end

      # Sets the position of the reading cursor
      def set_position(position)
        if (position != nil and position =~ /\A\d+\Z/)
          if (position < size)
            set_position(position)
          else
            raise(IOError, 'Position out of range', caller)
          end
        else
          raise(IOError, 'Position not valid. It must be an integer')
        end
      end
    
      # Check if the attachment should be saved, that is if a files was attached
      # using #file=
      def save_attachment?
        @save_attachment
      end
    
      # Save the attachment, copying the file from the temp_path to the data_path. This
      # is if a new file was attached using #file=
      def save_attachment
        return unless save_attachment?
        save_file
        @save_attachment = false
        true
      end

      # Delete the file connected to this record
      def destroy_attachment
        FileUtils.rm(full_filename) if File.exists?(full_filename)
      end

      # Save the attachment on the data_path directory. See #save_attachment
      def save_file
        FileUtils.mkdir_p(File.dirname(full_filename))
        FileUtils.cp(temp_path, full_filename)
        FileUtils.chmod(0644, full_filename)
      end

    end
  end
end
