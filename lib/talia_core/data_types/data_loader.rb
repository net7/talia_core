module TaliaCore
  module DataTypes

    # Used for attaching data items by laoding them from files and/or URLs. This will also attempt to
    # create the correct data type for any given file.
    module DataLoader

      module ClassMethods

        # Load the data from the given URL. If the mime_type option is given, the handler will always
        # use the parameter for the MIME type (which can be a Mime::Type object or a string like
        # 'text/html', or a mime type symbol).
        #
        # *Attention:* This method will return an *Array* of data objects. This is for those cases,
        # where a single data file will be processed into multiple objects (e.g. IIP data).
        #
        # If the mime type is not given, the method will attempt to automatically determine the
        # type, using the file extension or the response code.
        #
        # The :http_credentials option may be used to pass login information for http like this:
        #   http_credentials = { :http_basic_authentication => [login, password] }
        # See the openuri documentation for more.
        #
        # You may pass the :location parameter to identify the "location" value for the new
        # data record. In general, this is not neccessary. If the location is given, the system
        # will *always* attempt to determine the mime type through the location parameter, unless
        # an explicit mime type is given.
        def create_from_url(uri, options = {})
          options.to_options!
          options.assert_valid_keys(:mime_type, :location, :http_credentials)
          
          mime_type = options[:mime_type] 
          location = options[:location]
          # If a Mime type is given, use that.
          if(mime_type)
            mime_type = Mime::Type.lookup(mime_type) if(mime_type.is_a?(String))
          end

          data_records = []

          # Remove file:// from URIs to allow standard file URIs
          uri = file_url(uri)
          
          # We have diffent code paths for local and remote files. This is mainly because
          # the system will try to not open local files at all and just copy them around -
          # which will greatly speed up the operation.
          is_file = File.exist?(uri)

          location ||= File.basename(uri) if(is_file)
          # If we have a "standard" uri, we cut off at the last slash (the
          # File.basename would use the system file separator)
          location ||= uri.rindex('/') ? uri[(uri.rindex('/') + 1)..-1] : uri
          
          if(is_file)
            mime_type ||= mime_by_location(location)
            open_and_create(mime_type, location, uri, true)
          else
            open_from_url(uri, options[:http_credentials]) do |io|
              mime_type ||= Mime::Type.lookup(io.content_type)
              # Just in case we didn't get any content type
              mime_type ||= mime_by_location(location)
              open_and_create(mime_type, location, io, false)
            end
          end

        end

        private
        
        # Get the mime type from the location
        def mime_by_location(location)
          Mime::Type.lookup_by_extension(File.extname(location)[1..-1].downcase)
        end

        # The main loader. This will handle the lookup from the mapping and the creating of the
        # data objects. Depending on the setting of is_file, the source parameter will be interpreted
        # in a different way. If it is a file, the file name will be passed in here. If it is
        # a URL, the method will receive the io object of the open connection as the source
        def open_and_create(mime_type, location, source, is_file)
          data_type = MimeMapping.loader_type_from(mime_type)
          if(data_type.is_a?(Symbol))
            raise(ArgumentError, "No handler found for loading: #{data_type}") unless(self.respond_to?(data_type))
            MimeMapping.class_type_from(mime_type).send(data_type, mime_type, location, source, is_file)
          else
            raise(ArgumentError, "Registered handler for loading must be a method symbol or class. (#{data_type})") unless(data_type.is_a?(Class))
            data_record = data_type.new
            is_file ? data_record.create_from_file(location, source) : data_record.create_from_data(location, source)
            data_record.mime = mime_type.to_s
            data_record.location = location
            [ data_record ]
          end
        end


        
      end # Class methods end
      
    end # Closing modules and such
  end
end
