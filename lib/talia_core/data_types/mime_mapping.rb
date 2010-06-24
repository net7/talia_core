module TaliaCore
  module DataTypes

    # Mapping from Mime types to data classes and importing methods for DataRecord.
    #
    # See the DataTypes::DataLoader module to see how the import works. In a nutshell,
    # each MIME type can be connected either to a DataTypes::FileRecord type that will
    # be used for new data records, or the MIME type can be connected to a handler 
    # method that will do the creation.
    #
    # = Default Mappings
    #
    # See the source code of the mapping_hash method for the detailed default mapping.
    # It goes something like this: 
    #
    # * All image types (:jpeg, :tiff, :png, :gif, ...) use DataTypes::ImageData
    # * HTML, XML and all "transcription" types (:html, :xml, :tei, ...) use DataTypes::XmlData
    # * :text uses DataTypes::SimpleText
    # * :pdf uses DataTypes::PdfData
    # * The default (for unknow types) is to use DataTypes::FileRecord
    #
    # = Configure the MIME mappings for Talia
    # 
    # The mapping can be configured in Rails' initializer files (e.g. 
    # config/initializers/talia.rb):
    #
    #   TaliaCore::DataTypes::MimeMapping.add_mapping(:tiff, :image_data, :create_iip)
    #
    # Add a mapping for each MIME type that you need, or where you want to change
    # the default mapping
    class MimeMapping

      class << self

        # Gets the data class for the given mime type. For loaders configured
        # through add_mapping, this will always return the class corresponding
        # to data_class. (Otherwise it will return the data_class configured 
        # in the default mapping)
        def class_type_from(mime_type)
          mapping_for(mime_type)[:type]
        end

        # Return the "loader type" for the given MIME type. This will return the 
        # handler (as a symbol, see add_mapping) if set.
        # If no handler is set, it will return the data_class (as class_type_from). 
        def loader_type_from(mime_type)
          map = mapping_for(mime_type)
          map[:loader] || map[:type]
        end
        
        # Set a new mapping for the given MIME type. If only a class is given, this
        # will use the class to create new data records from. If a symbol is given
        # for data_class, this will take the corresponding class from
        # TaliaCore::DataTypes.
        #
        # = Examples
        #  
        #  # Uses DataTypes::ImageData#create_iip to create new records
        #  TaliaCore::DataTypes::MimeMapping.add_mapping(:tiff, :image_data, :create_iip)
        #  
        #  # Use the DataTypes::ImageData class for new data records, and create records
        #  # in the default way (using create_with_file or similar)
        #  TaliaCore::DataTypes::MimeMapping.add_mapping(:png, DataTypes::ImageData)
        def add_mapping(mime_type, data_class, handler = nil)
          mapping = {}
          if(!data_class.is_a?(Class))
            data_class = TaliaCore::DataTypes.const_get(data_class.to_s.camelize)
          end
          
          raise("Error: #{data_class} is not a valid data class.") unless(data_class.is_a?(Class) && (data_class <= DataRecord))
          
          mapping[:type] = data_class
          mapping[:loader] = handler.to_sym if(handler)
          mapping_hash[symbol_for(mime_type)] = mapping
          true
        end
        
        # Returns the current mapping. This will be automatically initialized with
        # the default mappings.
        def mapping_hash
          @mapping ||= {
            :xml => { :type => DataTypes::XmlData },
            :html =>{ :type => DataTypes::XmlData },
            :tei => { :type => DataTypes::XmlData },
            :tei_p5 => { :type => DataTypes::XmlData },
            :tei_p4 => { :type => DataTypes::XmlData }, 
            :gml => { :type => DataTypes::XmlData },
            :wittei => { :type => DataTypes::XmlData },
            :hnml => { :type => DataTypes::XmlData },
            :jpeg => { :type => DataTypes::ImageData },
            :tiff => { :type => DataTypes::ImageData },
            :png => { :type => DataTypes::ImageData },
            :gif => { :type => DataTypes::ImageData },
            :bmp => { :type => DataTypes::ImageData },
            :pdf => { :type => DataTypes::PdfData },
            :text => { :type => DataTypes::SimpleText },            
            # Default fallback handler
            :default => { :type => FileRecord }
          }
        end
        
        private
        
        # Returns the symbol that corresponds to a given MIME type. The MIME type
        # can be a Mime::Type object, a MIME string like 'text/html' or a MIME
        # symbol like :jpeg
        def symbol_for(mime_type)
          mime_type = Mime::Type.lookup(mime_type) unless(mime_type.is_a?(Mime::Type))
          mime_type.to_sym
        end

        # Return the mapping for the given MIME type. If no mapping is defined for the
        # MIME type, it will log a warning and use the "default" mapping.
        def mapping_for(mime_type)
          mapping = mapping_hash[symbol_for(mime_type)]
          TaliaCore.logger.warn { "No data class registered for mime type #{mime_type.inspect}, trying default handler." } unless(mapping)
          mapping ||= mapping_hash[:default]

          raise(ArgumentError, "No data class registered for type #{mime_type.inspect}") unless(mapping)
          mapping
        end

      end

    end

  end
end