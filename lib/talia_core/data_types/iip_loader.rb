module TaliaCore
  module DataTypes

    # Special module that contains the DataLoader methods to create IIP image data
    module IipLoader


      # Loads an image for the given file. This is a tad more complex than loading
      # the data into a data record: It will create both an IIP data object and
      # an Image data object. 
      def create_iip(mime_type, location, source, is_file)
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

      # Rewrite the file location for original image files (to .png)
      def orig_location(location)
        File.basename(location, File.extname(location)) + '.png'
      end

      # Indicates if the given mime type requires a conversion for the
      # original image
      def convert_original?(mime_type)
        !([:jpeg, :png].include?(mime_type.to_sym))
      end

      # Create the elements from a file
      def create_from_files(location, file, records)
        records.each { |rec| rec.create_from_file(location, file) }
      end

      # Create the elements from a stream
      def create_from_stream(location, io, records)
        data = io.read
        records.each { |rec| rec.create_from_data(location, data)}
      end

      # Attempts to create an IipData object with pre-prepared images if possible
      # Returns true if (and only if) the object has been created with existing
      # data. Always fals if the data_record is not an IipData object or the
      # :prepared_images option is not set.
      def prepare_image_from_existing!(iip_record, image_record, url, location)
        return false unless(iip_record.is_a?(TaliaCore::DataTypes::IipData) && image_record.is_a?(TaliaCore::DataTypes::ImageData))
        return false unless((prep = ENV['prepared_images']) && prep.to_s.downcase != 'no' && prep.to_s.downcase != 'false')

        file_ext = File.extname(url)
        file_base = File.basename(url, file_ext)

        thumb_file = File.join(import_options[:prepared_images], 'thumbs', "#{file_base}.gif")
        pyramid_file = File.join(import_options[:prepared_images], 'pyramids', "#{file_base}.tif")
        orig_file_pattern = File.join(import_options[:prepared_images], 'originals', "#{file_base}.*")
        # We need to fix the pattern, also the Dir[] doesn't like unescaped brackets
        orig_file_pattern.gsub!(/\[/, '\\[')
          orig_file_pattern.gsub!(/\]/, '\\]')
          orig_file_l = Dir[orig_file_pattern]
          raise(ArgumentError, 'Original find not found for ' + url) unless(orig_file_l.size > 0)
          orig_file = orig_file_l.first
          assit_block { %w(.jpg .jpeg .png).include?(File.extname(orig_file).downcase) }

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