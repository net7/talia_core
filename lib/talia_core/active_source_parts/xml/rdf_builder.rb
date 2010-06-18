module TaliaCore
  module ActiveSourceParts
    module Xml

      # Class for creating xml-rdf Data from a source. See the base class for more documentation
      class RdfBuilder < TaliaUtil::Xml::RdfBuilder

        # Builds the RDF for a source and returns the result as a string
        def self.build_source(source)
          make_xml_string { |build| build.write_source(source) }
        end

        # Builds the RDF for a source. This will include both the "direct" predicates as well as the
        # "inverse" (incoming predicates of a source)
        def write_source(source)
          # The source is written as subject, with all the triples nested inside it.
          @builder.rdf :Description, 'rdf:about' => source.uri.to_s do # Element describing this resource
            # loop through the predicates
            source.direct_predicates.each do |predicate|
              write_predicate(predicate, source[predicate])
            end
          end

          # Each of the inverse properties creates another subject entry, that just contains the one
          # triple relating it to the current source. (In this case, the subject and predicate entries
          # aren't merged any further)
          source.inverse_predicates.each do |predicate|
            source.inverse[predicate].each do |inverse_subject|
              @builder.rdf :Description, 'rdf:about' => inverse_subject do
                write_predicate(predicate, [source])
              end
            end
          end
        end


      end
    end
  end
end
