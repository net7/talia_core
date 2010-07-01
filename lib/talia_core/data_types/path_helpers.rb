module TaliaCore
  module DataTypes
  
    # Contains the helpers to obtain path information for data storage
    module PathHelpers
      
      module ClassMethods
        
        # Path used to store temporary files.
        def tempfile_path
          @@tempfile_path ||= File.join(TALIA_ROOT, 'tmp', 'data_records')
        end

        # Path used to store data files.
        def data_path
          @@data_path ||= File.join(TALIA_ROOT, 'data')
        end
        
      end      
      
      # Return the full file path for this record. If the relative
      # flag is set, this will only return the relative path inside
      # the data directory
      def file_path(relative = false)
        File.join(data_directory(relative), self.id.to_s)
      end
      
      # Gets the path that will be used for serving the image as a static
      # resource.
      #
      # This will return nil unless the <tt>static_data_prefix</tt> option
      # is set in the configuration. This option defines a URL prefix for
      # static files. 
      #
      # If the prefix is set, this method will return a URL that can be used
      # access the current file as a static asset. To use this, the data
      # directory has to be available on a web server at the 
      # <tt>static_data_prefix</tt>
      def static_path
        prefix = TaliaCore::CONFIG['static_data_prefix']
        return unless(prefix)
        prefix = N::LOCAL + prefix unless(prefix =~ /:\/\//)
        "#{prefix}/#{class_name}/#{("00" + self.id.to_s)[-3..-1]}/#{self.id}"
      end
      
      # See ClassMethods.tempfile_path
      def tempfile_path
        self.class.tempfile_path
      end
    
      # Return the _directory_ in which the file for the current record is stored.
      # If the relative flag is set, it will only return the relative path
      # inside the main data directory.
      #
      # The paths will look something like: <tt>.../XmlData/031/</tt>
      def data_directory(relative = false)
        class_name = self.class.name.gsub(/(.*::)/, '')
        if relative == false
          File.join(TaliaCore::CONFIG["data_directory_location"], class_name, ("00" + self.id.to_s)[-3..-1])
        else
          File.join(class_name, ("00" + self.id.to_s)[-3..-1])
        end
      end
    
      # See ClassMethods.data_path
      def data_path
        self.class.data_path
      end
      
      # Cached version of #file_path
      def full_filename
        @full_filename ||= self.file_path #File.join(data_path, class_name, location)
      end
      
      # See ClassMethods.extract_filename
      def extract_filename(file_data)
        self.class.extract_filename(file_data)
      end
      
    end
  
  end
end
