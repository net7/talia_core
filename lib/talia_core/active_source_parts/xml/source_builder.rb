# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module ActiveSourceParts
    module Xml
      
      # Class to build source representations of ActiveSource objects. Talia 
      # uses a simple XML format to encode the Source Object. The format
      # maps easily to a Hash as it is used for the new or write_attributes 
      # methods:
      #
      #   <sources>
      #     <source>
      #       <attribute>
      #         <predicate>http://foobar/</predicate>
      #         <object>http://barbar/</object>
      #       </attribute>
      #       ...
      #     </source>
      #     <source>
      #       <attribute>
      #         <predicate>http://foobar/bar/</pedicate>
      #         <value>val</value>
      #         <object>http://some_url</object>
      #         <value>another</value>
      #         ...
      #       </attribute>
      #       ...
      #     </source>
      #     ...
      #   </sources>
      #
      # Also see the parent class, TaliaUtil::Xml::BaseBuilder, for more information
      class SourceBuilder < TaliaUtil::Xml::BaseBuilder
        
        # Builds the XML for a single source, and returns the result as
        # a string
        def self.build_source(source)
          make_xml_string { |build| build.write_source(source) }
        end
        
        # Build the XML for a single source.
        def write_source(source)
          @builder.source do 
            source.attributes.each { |attrib, value| write_attribute(attrib, value) }
            source.direct_predicates.each { |pred| write_attribute(pred, source[pred]) } 
          end
        end
        
        private
        
        # Builds an attribute tag (with contents) in a source
        def write_attribute(predicate, values)
          predicate = predicate.respond_to?(:uri) ? predicate.uri.to_s : predicate.to_s
          values = [ values ] unless(values.respond_to?(:each))
          @builder.attribute do 
            @builder.predicate { @builder.text!(predicate) }
            values.each { |val| write_target(val) }
          end
        end
        
        # Writes a value or object tag, depeding on the target.
        def write_target(target)
          if(target.respond_to?(:uri))
            @builder.object { @builder.text!(target.uri.to_s) }
          else
            @builder.value { @builder.text!(target.to_s) }
          end
        end
        
        # Build the structure for the XML file and pass on to
        # the given block
        def build_structure
          @builder.sources do 
            yield
          end
        end
        
      end
    
    end
  end
end