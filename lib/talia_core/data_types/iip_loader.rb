require 'tmpdir'

module TaliaCore
  module DataTypes

    # Loader module for IipData records. IIP records should always be created
    # by using the #create_iip method in this module as a loader. Check the
    # DataLoader documentation to find out how to configure loaders for 
    # different MIME types.
    #
    # = How does this work?
    #
    # The loader will take the original image, and create two new DataRecords
    # which contain three different versions of the image:
    #
    # * An ImageData record will contain the original version of the image.
    #   This will contain the original file if the original is a jpeg or png 
    #   image. Otherwise it will be converted to png.
    # * An IipData record which contains a thumbnail of the original image and
    #   create the pyramidal version of it in the IIP server's directory. The
    #   location of the IipData will contain the path to the pyramidal image
    #   on the server
    #
    # = Using existing images
    #
    # Creating the pyramid images can be a time-consuming process and it may
    # be useful to separate this from the actual import process (if, for example
    # you want to re-import the same data set several times). The Talia
    # distribution contains a <tt>prepare_images</tt> script that will take the
    # original files from a given directory and create the converted files in
    # another location, using the subdirectories <tt>thumbs</tt>, <tt>pyramids</tt>
    # and <tt>originals</tt> respectively.
    #
    # If a directory with "prepared files" exists, the <tt>prepared_images</tt>
    # option in the _environment_ to the path to the directory. When the loader
    # see that environment variable, it will automatically load the prepared
    # images from that directory.
    module IipLoader


      # Loads an image for the given file. This is a tad more complex than loading
      # the data into a data record: It will create both an IIP data object and
      # an Image data object. If the original is an IO stream, a temp file will
      # be created for the conversions. See above for more.
      def create_iip(mime_type, location, source, is_file)
        # Create the new records
        iip_record = TaliaCore::DataTypes::IipData.new
        image_record = TaliaCore::DataTypes::ImageData.new
        records = [iip_record, image_record]
        return records if(is_file && prepare_image_from_existing!(iip_record, image_record, source, location))

        if(convert_original?(mime_type))
          # We have an image that needs to be converted
          open_original_image(source, is_file, mime_type) do |io|
            create_from_stream(location, io, records)
            image_record.location = orig_location(location)
          end
        else
          if(is_file)
            create_from_files(location, source, records) 
          else 
            create_from_stream(location, source, records)
          end
        end
        # IipRecord is always a (multi-leve) tiff
        iip_record.mime = 'image/tiff'

        records
      end

      # Rewrite the <tt>location</tt> field (filename) for "original image" data
      # record, changing the extension to .png
      def orig_location(location)
        File.basename(location, File.extname(location)) + '.png'
      end

      # Indicates if an original image with the given mime type
      # should be converted to png for the "original image" record
      def convert_original?(mime_type)
        !([:jpeg, :png].include?(mime_type.to_sym))
      end

      # Pass in the empty data records (for original and iip), and
      # fill each one by calling #create_from_file with the 
      # given file
      def create_from_files(location, file, records)
        records.each { |rec| rec.create_from_file(location, file) }
      end

      # Pass in the empty data records (for original and iip), and
      # fill them by reading the data from the io stream and
      # calling  #create_from_data on each record
      def create_from_stream(location, io, records)
        data = io.read
        records.each { |rec| rec.create_from_data(location, data)}
      end

      # Attempts to create the records from pre-prepared images, if possible.
      # Returns true if (and only if) the object has been created with existing
      # data. Always false if the data_record is not an IipData object or the
      # <tt>prepared_images</tt> option is not set.
      # 
      # If this method returns true, the images have been successfully prepared
      # from pre-prepared images.
      def prepare_image_from_existing!(iip_record, image_record, url, location)
        return false unless(iip_record.is_a?(TaliaCore::DataTypes::IipData) && image_record.is_a?(TaliaCore::DataTypes::ImageData))
        return false unless((prep = ENV['prepared_images']) && prep.to_s.downcase != 'no' && prep.to_s.downcase != 'false')

        file_ext = File.extname(url)
        file_base = File.basename(url, file_ext)

        # Get the file paths for each prepared image: thumb, pyramid and original
        thumb_file = File.join( ENV['prepared_images'], 'thumbs', "#{file_base}.gif")
        pyramid_file = File.join( ENV['prepared_images'], 'pyramids', "#{file_base}.tif")
        # Use a pattern for the original file, since we don't know the extensions
        orig_file_pattern = File.join(ENV['prepared_images'], 'originals', "#{file_base}.*")
        # We need to fix the pattern
        orig_file_pattern.gsub!(/\[/, '\\[') # Escape brackets, Dir[] doesn't like them
        orig_file_pattern.gsub!(/\]/, '\\]')
        orig_file_l = Dir[orig_file_pattern]
        raise(ArgumentError, 'Original find not found for ' + url) unless(orig_file_l.size > 0)
        orig_file = orig_file_l.first # Original is the first file matching the pattern
        assit_block { %w(.jpg .jpeg .png).include?(File.extname(orig_file).downcase) }

        # Now create the existing records from the files
        iip_record.create_from_existing(thumb_file, pyramid_file)
        image_record.create_from_file(location, orig_file)

        true
      end

      # Little helper to decide how to open the original image
      def open_original_image(thing, is_file, current_type, &block)
        if(is_file)
          open_original_image_file(thing, &block) 
        else
          open_original_image_stream(thing, current_type, &block)
        end
      end

      # Same as open_original_image_file, but getting the data from a stream.
      # This writes the data to a temp file and calls open_original_file on it
      # The temporary file is deleted after the operation
      def open_original_image_stream(io, type, &block)
        # First load this from the web to a temp file
        tempfile = File.join(Dir.tmpdir, "talia_down_#{rand 10E16}.#{type.to_sym}")
        begin
          File.open(tempfile, 'w') do |fio|
            fio << io.read # Download the file
          end
          assit(File.exist?(tempfile))
          open_original_image_file(tempfile, &block)
        ensure
          FileUtils.rm(tempfile) if(File.exist?(tempfile))
        end
      end

      # Opens the "original" image for the given file. This will convert the
      # image to PNG image and the yield the io object for the PNG.
      def open_original_image_file(filename)
        converted_file = File.join(Dir.tmpdir, "talia_convert_#{rand 10E16}.png")
        begin
          TaliaUtil::ImageConversions.to_png(filename, converted_file)
          File.open(converted_file) do |io|
            yield(io)
          end
        ensure
          FileUtils.rm(converted_file) if(File.exist?(converted_file))
        end
      end


    end # Ending modules and such
  end
end