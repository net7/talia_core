# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

# BY RIK
module TaliaCore
  module ActiveSourceParts
    module Xml

      # Class for creating LOD-compliant XML/RDF Data from an active_source. 
      # See the parent class, TaliaUtil::Xml::RdfBuilder, for more information.
      class LodRdfBuilder < TaliaUtil::Xml::RdfBuilder

        # Builds the RDF for a source and returns the result as a string
        def self.build_source(source, check_predicates=true)
          @check_predicates = check_predicates
          make_xml_string { |build| build.write_source(source) }
        end

        # Builds the RDF for a source. 
        def write_source(source)
          write_metadata source
          # The description.
          write_description source
          # Backlinks
          write_backlinks source
          # Related descriptions
          write_related_descriptions source
        end

        def write_metadata(source)
          # TODO: check if following rdfs:isDefinedBy is correct to find the information resource.
          if metadata_source = source[N::RDFS.isDefinedBy].first
            write_description metadata_source
          end
        end

        def write_description(source)
          @builder.rdf :Description, 'rdf:about' => source.uri.to_s do
            source.direct_predicates.each do |predicate|
              values = source[predicate].respond_to?(:each) ? source[predicate] : [source[predicate]]
              write_predicate(predicate, values, @check_predicates)
            end
          end
        end

        def write_backlinks(source)
          source.inverse_triples.each do |triple|
            if triple[:subject_class].lod?
              @builder.rdf :Description, 'rdf:about' => triple[:subject] do
                write_predicate(triple[:predicate], [source], @check_predicates)
              end
            end
          end
        end

        def write_related_descriptions(source)
          source.class.my_property_options.each do |related, properties|
            unless properties[:singular_property]
              source[related].each do |related_source|
                write_description related_source
              end
            end
          end
        end
      end
    end
  end
end
