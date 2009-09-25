module TaliaCore
  module DataTypes

    # This is the default mapping from mime types to the data types. If a symbol is given,
    # the system will assume that it has to create that method to create the data.
    #
    # If a class is given, it will create a data object of that type
    DEFAULT_MAPPING = {
      :xml => { :type => XmlData },
      :html =>{ :type => XmlData },
      :tei => { :type => XmlData },
      :jpeg => { :type => ImageData, :loader => :create_iip },
      :tiff => { :type => ImageData, :loader => :create_iip },
      :png => { :type => ImageData, :loader => :create_iip },
      :gif => { :type => ImageData, :loader => :create_iip },
      :pdf => { :type => PdfData },
      :text => { :type => SimpleText }
    }
    
    # Mapping from Mime types to data classes and importing methods. Currently uses a fixed 
    # default mapping
    module MimeMapping
      
      def mapping_for(mime_type)
        mime_type = Mime::Type.lookup(mime_type) if(mime_type.is_a?(String))
        mapping = DEFAULT_MAPPING[mime_type.to_sym]
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
      
      
    end
    
  end
end