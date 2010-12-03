# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module DataTypes

    # Used for attaching data items by laoding them from files and/or URLs. This will also attempt to
    # create the correct data type for any given file. See DataLoader::ClassMethods
    
    module DataLoader

      # The create_from_url method will create a new FileRecord from a 
      # data source (file or web URL). The exact mechanism for creating
      # the record will depend on the MIME type of the data.
      #
      # =How the MIME type is determined
      # 
      # * If the :mime_type options is provided, the system will _always_ use 
      #   that MIME type for the new record
      # * If the :location option is provided, the system will _always_ attempt
      #   to determine the MIME type from the "file extension" of the location,
      #   unless the :mime_type option is set
      # * If the uri is a file, the system will use the file extension to
      #   determine the MIME type automatically
      # * If the uri is a web URL, the system will first check if the server
      #   provided a MIME type in the response. If not, it will use the
      #   "file extension" of the uri to determine the MIME type as above
      #
      # =If the loader is a FileRecord class (no loader method)
      #
      # If no loader method is specified, the loader will simply create a 
      # new FileRecord object of the type specified in the loader. It will
      # then use create_from_file (for files) or create_from_data (for 
      # a web uri) to load the data into the new record. 
      #
      # Example:
      # 
      #  # Set a loader for png (usually done in the initializer, 
      #  # this one is equal to the default)
      #  TaliaCore::DataTypes::MimeMapping.add_mapping(:png, DataTypes::ImageData)
      #  
      #  # Call the loader
      #  FileRecord.create_from_url('test.png')
      #  # This will result in the following:
      #  # DataTypes::ImageData.new.create_from_file('test.png', 'test.png')
      # 
      # = If the loader is a method
      # 
      # In case a loader method is specified, the system will simply call that
      # method on the _class_ provided by the loader. The loader method must
      # take the following paramters: mime_type, location, source, is_file:
      #
      # * _mime_type_ is the MIME type for the object being imported
      # * _location_ is the location string for the current record. This
      #   is either the location passed in as an option, or the base name
      #   of the uri
      # * _source_ is either the io object from which to read the data,
      #   or a file name
      # * _is_file_ is set to true in case the _source_ is a file name
      #
      # Example:
      # 
      #  # Set the handler for tiff files, usually done in the initializer
      #  TaliaCore::DataTypes::MimeMapping.add_mapping(:tiff, :image_data, :create_iip)
      #  
      #  # Call the loader
      #  FileRecord.create_from_url('test.tiff')
      #  # This will result in the following:
      #  # DataTypes::ImageData.create_iip(Mime::Type.lookup(:tiff), 'test.tif', 'test.tif', true)
      module ClassMethods

        # Load data from the given url and create FileRecord objects,
        # as appropriate.
        #
        # The way the FileRecord is created is determined by the MIME type 
        # for the data. Talia has a "loader" for each MIME type - see the 
        # MimeMapping class to see the default loaders and to find out how to
        # configure them.
        #
        # Each "loader" contains the FileRecord class that is used for new
        # records, and (optionally) the name of a loader method which 
        # creates the new records. If no loader method is provided, a default
        # mechanism is used.
        #
        # *Options*
        #
        # [*mime_type*] Specify the MIME type to use for the import. The parameter can either be
        #               a MIME::TYPE object, a string like 'text/html' or a MIME type symbol like :jpeg
        # [*http_credentials*] Credentials for http authentication, if the uri requires
        #                      that. These are the same options that openuri accepts, so see
        #                      the documentation for that library for more information.
        #                      _Example_: :http_credentials => { :http_basic_authentication => [login, password] }
        # [*location*] The location (e.g. filename) for the new FileRecord. If a location is
        #              given, it will _always_ be used to determine the MIME type, unless a
        #              MIME type is passed explicitly as an option
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
          
          assit(!location.blank?)
          
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
          extname = File.extname(location)[1..-1]
          assit(!extname.blank?, 'No extname found for ' << location)
          Mime::Type.lookup_by_extension(extname.downcase)
        end

        # The main loader. This will handle the lookup from the mapping and the creating of the
        # data objects. Depending on the setting of is_file, the source parameter will be interpreted
        # in a different way. If it is a file, the file name will be passed in here. If it is
        # a URL, the method will receive the io object of the open connection as the source
        def open_and_create(mime_type, location, source, is_file)
          data_type = MimeMapping.loader_type_from(mime_type)
          if(data_type.is_a?(Symbol))
            type = MimeMapping.class_type_from(mime_type)
            raise(ArgumentError, "No handler found for loading: #{data_type}") unless(type.respond_to?(data_type))
            type.send(data_type, mime_type, location, source, is_file)
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
