module TaliaCore
  module DataTypes
    
    # Mapping from Mime types to data classes and importing methods. Currently uses a fixed 
    # default mapping. If the mime type is not known, it will use a fallback default handler.
    module MimeMapping
      
      def mapping_for(mime_type)
        mime_type = Mime::Type.lookup(mime_type) if(mime_type.is_a?(String))
        mapping = mapping_hash[mime_type.to_sym]
        TaliaCore.logger.warn { "No data class registered for mime type #{mime_type.inspect}, trying default handler." } unless(mapping)
        mapping ||= mapping_hash[:default]
        
        raise(ArgumentError, "No data class registered for type #{mime_type.inspect}") unless(mapping)
        mapping
      end
      
      # Gets the data class for the given mime type
      def class_type_from(mime_type)
        mapping_for(mime_type)[:type]
      end
      
      def loader_type_from(mime_type)
        map = mapping_for(mime_type)
        map[:loader] || map[:type]
      end
      
      # Currently there is only the default mapping
      def mapping_hash
        @mapping ||= {
          :xml => { :type => XmlData },
          :html =>{ :type => XmlData },
          :tei => { :type => XmlData },
          :tei_p5 => { :type => XmlData },
          :tei_p4 => { :type => XmlData }, 
          :gml => { :type => XmlData },
          :wittei => { :type => XmlData },
          :hnml => { :type => XmlData },
          :jpeg => { :type => ImageData, :loader => :create_iip },
          :tiff => { :type => ImageData, :loader => :create_iip },
          :png => { :type => ImageData, :loader => :create_iip },
          :gif => { :type => ImageData, :loader => :create_iip },
          :pdf => { :type => PdfData },
          :text => { :type => SimpleText },
          # Default fallback handler
          :default => { :type => FileRecord }
        }
      end
      
      
    end
    
  end
end