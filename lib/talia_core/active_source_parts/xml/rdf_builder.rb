module TaliaCore
  module ActiveSourceParts
    module Xml

      # Class for creating xml-rdf data
      class RdfBuilder < TaliaUtil::Xml::RdfBuilder

        def self.build_source(source)
          make_xml_string { |build| build.write_source(source) }
        end

        # Writes a complete source to the rdf
        def write_source(source)
          @builder.rdf :Description, 'rdf:about' => source.uri.to_s do # Element describing this resource
            # loop through the predicates
            source.direct_predicates.each do |predicate|
              write_predicate(predicate, source[predicate])
            end
          end
        end

        
      end
    end 
  end
end