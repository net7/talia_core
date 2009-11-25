module TaliaCore
  
  # Handling of RDF string values. These values can contain both locale (language)
  # and type information. (E.g. "Some value^^string@en")
  #
  # This class will parse the value string an make all elements available as separate
  # accessors.
  class PropertyString < String
    
    attr_accessor :type, :lang
    
    # Create a new object by parsing the given property string
    def self.parse(property_string)
      self.new.parse(property_string)
    end
    
    # Create a new object from the given values. No parsing is done here.
    def initialize(property_string = '', language = nil, type = nil)
      @lang = language
      @type = type
      self.replace(property_string)
    end
    
    # Parses the given string into a PropertyString
    def parse(property_string)
      # First split for the type
      type_split = property_string.split('^^')
      # Check if any of the elements contains a language string
      type_split = type_split.collect { |el| extract_lang(el) }
      @type = (type_split.size > 1) ? type_split.last : nil
      self.replace(type_split.first || '')
    end

    # Gives the "internal representation" - this should be equivalent
    # to the string from which the object was created
    def to_rdf
      value = self.clone
      value << '^^' << type if(type)
      value << '@' << lang if(lang)
      value
    end
    
    # Inspect shows the real content
    def inspect
      "\"#{self}\" <lang: #{lang.inspect} - type: #{type.inspect}>"
    end
    
    private

    # Helper to extract a language string. The lang value, if any, will be added to the hash
    def extract_lang(value)
      lang_split = value.split('@')
      @lang ||= (lang_split.size > 1) ? lang_split.last : nil
      lang_split.first || ''
    end
    
  end
end