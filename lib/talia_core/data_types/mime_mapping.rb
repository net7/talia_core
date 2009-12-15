module TaliaCore
  module DataTypes

    # Mapping from Mime types to data classes and importing methods. Currently uses a fixed 
    # default mapping. If the mime type is not known, it will use a fallback default handler.
    #
    # The mapping can be configured in Rails' initializer files. Example:
    #
    #   TaliaCore::DataTypes::MimeMapping(:tiff, :image_data, :create_iip)
    class MimeMapping

      class << self

        # Gets the data class for the given mime type
        def class_type_from(mime_type)
          mapping_for(mime_type)[:type]
        end

        def loader_type_from(mime_type)
          map = mapping_for(mime_type)
          map[:loader] || map[:type]
        end
        
        # Set a new mapping for the given MIME type. If only a class is given, this
        # will use the class to create new data records from. If a symbol is given
        # for the class name, this will take the corresponding class from
        # TaliaCore::DataTypes.
        #
        # The loader method can be a symbol, if given it must correspond to a *class* 
        # method that can be called on type_class and which accepts exactly 4 parameters,
        # which will be passed in during record creation
        # 
        # * Mime type of the record 
        # * 'location' field of the record
        # * The record source - this is a descriptive string with either the url
        #   or the file name from which the data should be fetched
        # * The is_file flag. This will be true if the source is the name of a
        #   regular file. Otherwise, the source field should be interpreted as
        #   a URL.
        # == Example handler method
        #
        #   def data_loader(mime_type, location, source, is_file)
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
        
        private

        def symbol_for(mime_type)
          mime_type = Mime::Type.lookup(mime_type) unless(mime_type.is_a?(Mime::Type))
          mime_type.to_sym
        end

        def mapping_for(mime_type)
          mapping = mapping_hash[symbol_for(mime_type)]
          TaliaCore.logger.warn { "No data class registered for mime type #{mime_type.inspect}, trying default handler." } unless(mapping)
          mapping ||= mapping_hash[:default]

          raise(ArgumentError, "No data class registered for type #{mime_type.inspect}") unless(mapping)
          mapping
        end

        # Currently there is only the default mapping
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

      end

    end

  end
end