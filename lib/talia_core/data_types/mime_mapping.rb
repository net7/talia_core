module TaliaCore
  module DataTypes
    
    # Mapping from Mime types to data classes and importing methods. Currently uses a fixed 
    # default mapping
    module MimeMapping
      
      def mapping_for(mime_type)
        mime_type = Mime::Type.lookup(mime_type) if(mime_type.is_a?(String))
        mapping = mapping_hash[mime_type.to_sym]
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
      
      # Currently this is only the default mapping
      def mapping_hash
        @mapping ||= {
          :xml => { :type => XmlData },
          :html =>{ :type => XmlData },
          :tei => { :type => XmlData },
          :hnml => { :type => XmlData },
          :jpeg => { :type => ImageData, :loader => :create_iip },
          :tiff => { :type => ImageData, :loader => :create_iip },
          :png => { :type => ImageData, :loader => :create_iip },
          :gif => { :type => ImageData, :loader => :create_iip },
          :pdf => { :type => PdfData },
          :text => { :type => SimpleText }
        }
      end
      
      
    end
    
  end
end