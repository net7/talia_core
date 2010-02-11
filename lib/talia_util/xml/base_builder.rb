module TaliaUtil
  module Xml
    
    # Base class for builders that create XML representations. This uses a Builder::XmlMarkup object
    # in the background which does the actual XML writing.
    # 
    # All builders will be used through the #open method, which can be passed either a Builder::XmlMarkup
    # object, or the options to create one.
    #
    # Subclasses must provide a build_structure method that creates the outer structure of the XML
    class BaseBuilder
      
      # Creates a new builder. The options are equivalent for the options of the
      # underlying Xml builder. The builder itself will be passed to the block that
      # is called by this method.
      # If you pass a :builder option instead, it will use the given builder instead
      # of creating a new one
      def self.open(options)
        my_builder = self.new(options)
        my_builder.send(:build_structure) do
          yield(my_builder)
        end
      end
      
      # Builds to a string, using a default builder. This returns the string and otherwise 
      # works like #open
      def self.make_xml_string
        xml = ''
        open(:target => xml, :indent => 2) do |builder|
          yield(builder)
        end
        
        xml
      end
      
      private
      
      # Create a new builder
      def initialize(options)
        @builder = options[:builder]
        @builder ||= Builder::XmlMarkup.new(options)
      end
      
    end
    
  end
end