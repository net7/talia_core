# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module DataTypes
    
    # Class to manage IIP Image data type. This differs from the "normal" 
    # file record in various ways:
    #
    # * The record itself only contains a thumbnail version of the image as 
    #   data (#get_thumbnail will return the file data for the thumbnail)
    # * The location of the record contains the path to the image on the
    #   IIP server. This is also returned by #iip_server_path
    # * The records should be created using the IipLoader - see DataLoader
    #   to find out how to configure Talia to do that
    #
    # = What is IIP?
    #
    # IIP is a protocol to use "pyramidal images" - which are images which
    # contain a tiled version of the original image in various resolutions.
    # It is used to serve high-resolution images in a way that a client can 
    # request only the portion of the image that is currently needed.
    #
    # = How does IIP work with Talia?
    #
    # To use IIP, an IIP server is needed.
    # The IIP client will connect to the server and request an image from using
    # HTTP requests. 
    #
    # The IIP server is a separate piece of sofware, which is not part of
    # Talia. The one commonly used is http://iipimage.sourceforge.net/ which
    # runs as a fastcgi module in Apache (or another web server).
    #
    # For talia this means:
    #
    # * The pyramidal images have to be put in a place where the IIP server can
    #   access them - they do *not* go in the normal data directory.
    # * The location of the directory for the pyramidal images can be configured
    #   as <tt>iip_root_directory_location</tt> in the <tt>talia_core.yml</tt>
    #   file.
    # * The <tt>location</tt> field of each IipData record contains the _relative_
    #   path for accessing the file on the IIP server.
    # * The URI of the server itself can be set in <tt>talia_core.yml</tt> as
    #   <tt>iip_server_uri</tt>
    #
    # = How can the IIP images be shown in Talia?
    #
    # There are several clients or "viewers" for IIP images available, and one
    # is also included in the "muruca_widgets" gem that can be installed in
    # addition to talia.
    #
    # Generally you'll have to include the client in your view templates, and
    # use the #iip_server_uri and #iip_server_path to point it to the image
    # on the server.
    #
    # Obviously you'll also need a running IIP server.
    #
    # = What are the requirements for IIP?
    #
    # Apart from the IIP server itself, you'll need some software to actually
    # create the pyramidal images - see the TaliaUtil::ImageConversions class for details.
    class IipData < FileRecord
      
      # Returns the IIP server configured for the application. This is usually the
      # value configured as the <tt>iip_server_uri</tt> in the <tt>talia_core.yml</tt>
      def self.iip_server_uri
        TaliaCore::CONFIG['iip_server_uri'] ||= 'http://localhost/fcgi-bin/iipsrv.fcgi'
      end
      
      # This is the mime type for the thumbnail. Always gif.
      def set_mime_type
        self.mime = 'image/gif'
      end
      
      alias :get_thumbnail :all_bytes
     
      # Create a new record from an existing thumb and pyramidal image. 
      # This is used to make a record from pre-existing "prepared" images
      # and does not do any image conversion.
      def create_from_existing(thumb, pyramid, delete_originals = false)
        @file_data_to_write = [thumb, pyramid]
        @delete_original_file = delete_originals
        self.location = ''
      end
      
      # The relative path to the image on the IIP server
      def iip_server_path
        self.location
      end
      
      # Callback to write the data when the record is saved, which is more involved than
      # the same method on the superclass.
      #
      # * If the thumb and pyramid file are already available, they are used directly 
      #   with #direct_write!
      # * Otherwise it will take the original file and pass it through the TaliaUtil::ImageConversions
      #   to create the thumbnail and pyramidal image.
      # * Any temporary files created in the process are cleaned up afterwards
      def write_file_after_save
        return unless(@file_data_to_write)
        
        # Check if we have the converted images already. In this case we write
        # them to the appropriate directories directly and call the super method
        return super if(direct_write!)
        
        # "Prepare" the original file for conversion, indicate if a temp file is being used
        original_file_path, orig_is_temp = prepare_original_file
        # Check if we need to delete the original/temp file
        will_delete_source = orig_is_temp || @delete_original_file
        # Path to the temporary thumbnail file
        destination_thumbnail_file_path = File.join(Dir.tmpdir, "thumbnail_#{random_tempfile_filename}.gif")
        
        begin
          self.class.benchmark("\033[36mIipData\033[0m Making thumb and pyramid for #{self.id}", Logger::INFO) do
          
            # Create the thumbnail at the temporary location
            TaliaUtil::ImageConversions::create_thumb(original_file_path, destination_thumbnail_file_path)
            # Create the pyramidal image from the original
            create_pyramid(original_file_path)
        
            # Run the super implementation for the thumbnail, by using the temporary thumb file as the "data"
            @file_data_to_write = DataPath.new(destination_thumbnail_file_path)
            # The temp thumb file needs to be deleted by the superclass
            @delete_original_file = true
          
          end # end benchmarking
          super
          
        ensure
          # Delete the temporary "original" file, if necessary
          File.delete original_file_path if(File.exists?(original_file_path) && will_delete_source)
        end
      end
      
      
      # Checks if there if the thumb and pyramidal file already exist and can simply be moved
      # to the correct location.
      #
      # If yes, the method will move or copy the files to the correct locations, and return true
      # Otherwise, the method will do nothing and return false.
      def direct_write!
        # If we have an array of data files, we can assume that these are 
        # pre-prepared thumb and pyramid images
        return false unless(@file_data_to_write.kind_of?(Array))
        
        thumb, pyramid = @file_data_to_write
        self.class.benchmark("\033[36mIipData\033[0m Direct write for #{self.id}", Logger::INFO) do
          prepare_for_pyramid # Setup the record for the new image
          # Copy or move the pyramid file to the correct location
          copy_or_move(pyramid, get_iip_root_file_path)
        
        end # end benchmark
        
        # Set the thumb file as the data file for the current FileRecord (which
        # is automatically handled by the superclass)
        @file_data_to_write = DataPath.new(thumb)
        
        true
      end

      # This prepares the original file that needs to be converted. This will
      # see if the data to be written is binary data or a file path. If it
      # is binary data, it will create a temporary file on the disk.
      #
      # This returns an array with two elements: The name of the file to 
      # be used (a file system path) and a flag indicating if the file is
      # a temporary file or not.
      def prepare_original_file
        if(@file_data_to_write.is_a?(DataPath))
          [@file_data_to_write, false]
        else
          temp_file = File.join(Dir.tmpdir, "original_#{random_tempfile_filename}")
          # write the original file
          File.open(temp_file, 'w') do |original_file|
            if(@file_data_to_write.respond_to?(:read))
              original_file << @file_data_to_write.read
            else
              original_file << @file_data_to_write
            end
          end
          
          [temp_file, true]
        end
      end
      
      # Prepare for copying or creating the pyramid image. Sets the <tt>location</tt>
      # of the record and creates the directory to store the IIP images
      def prepare_for_pyramid
        # set location
        self.location = get_iip_root_file_path(true)
        
        # create data directory path
        FileUtils.mkdir_p(iip_root_directory)
      end
      
      # Creates the pyramid image for IIP by running the configured system
      # command. This automatically creates the file in the correct location 
      # (IIP root). The conversion is done using the TaliaUtil::ImageConversions
      def create_pyramid(source)
        # check if file already exists
        raise(IOError, "File already exists: #{get_iip_root_file_path}") if(File.exists?(get_iip_root_file_path))
       
        prepare_for_pyramid

        TaliaUtil::ImageConversions::create_pyramid(source, get_iip_root_file_path)
      end
      
      # Return the iip root directory for a specific iip image file. This is the
      # directory where the pyramid file will be stored on disk.
      #
      # If the <tt>relative</tt> flag is set, it will return a relative path.
      def iip_root_directory(relative = false)
        # TODO: The relative paths are (also?) used for web access, is it o.k. to
        # use File.join ?
        if relative == false
          File.join(TaliaCore::CONFIG["iip_root_directory_location"], ("00" + self.id.to_s)[-3..-1])
        else
          File.join(("00" + self.id.to_s)[-3..-1])
        end
      end
      
      # Return the full file path for the IIP image. See #iip_root_directory
      def get_iip_root_file_path(relative = false)
        File.join(iip_root_directory(relative), self.id.to_s + '.tif')
      end
      
      private
  
      # Generates a unique filename for a Tempfile. 
      def random_tempfile_filename
        "#{rand 10E16}"
      end
      
    end
    
  end
end
