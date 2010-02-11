module TaliaUtil
  module Xml
    # Class for creating xml-rdf data
    class RdfBuilder < BaseBuilder

      # Writes a simple "flat" triple. If the object is a string, it will be
      # treated as a "value" while an object (ActiveSource or N::URI) will be treated
      # as a "link".
      #
      # Throws an exception if the predicate cannot be turned into a namespaced
      # representation
      def write_triple(subject, predicate, object)
        subject = subject.respond_to?(:uri) ? subject.uri.to_s : subject
        predicate = predicate.respond_to?(:uri) ? predicate : N::URI.new(predicate) 
        @builder.rdf :Description, "rdf:about" => subject do
          write_predicate(predicate, [ object ])
        end
      end

      # Writes all the given triples.
      def write_triples(triples)
        triples.each do |triple|
          write_triple(*triple)
        end
      end
      
      # 
      def self.open_for_triples(triples, options = nil)
        my_builder = self.new(options)
        
        triple_hash = my_builder.send(:prepare_triples, triples)
        
        my_builder.send(:build_structure) do
          my_builder.send(:write_for_triples, triple_hash)
        end
      end
      

      def self.xml_string_for_triples(triples)
        xml = ''
        open_for_triples(triples, :target => xml, :indent => 2)
        xml
      end

      private 
      
      
      def prepare_triples(triples)
        triple_hash = {}
        triples.each do |triple|
          subject = triple.shift
          subject = subject.to_s
          predicate = triple.first.to_uri
          namespaced_predicate = predicate.to_name_s
          if(predicate == namespaced_predicate)
            # We have an unknown namespace
            namespaced_predicate = make_predicate_namespace(predicate)
          end
          triple_hash[subject] ||= {}
          triple_hash[subject][N::URI.new(namespaced_predicate)] ||= [] 
          triple_hash[subject][N::URI.new(namespaced_predicate)] << triple.last
        end
        triple_hash
      end
      
      # Write for the open_for_triples
      def write_for_triples(triple_hash)
        triple_hash.each do |subject, values|
          @builder.rdf :Description, 'rdf:about' => subject.to_uri.to_name_s do # Element describing this resource
            values.each do |predicate, objects|
              write_predicate(predicate, objects, false)
            end
          end
        end
      end
      
      def make_predicate_namespace(predicate)
        pred_uri = URI.parse(predicate.to_s)
        path_parts = split_uri!(pred_uri)
        raise(ArgumentError, "Illegal predicate URL #{predicate}") if(path_parts[0].blank? || path_parts[1].blank?)
        namespace = make_namespace(pred_uri)
        "#{namespace}:#{path_parts[1]}"
      end

      def split_uri!(uri)
        if(uri.fragment)
          fragment = uri.fragment
          uri.fragment = '' 
          [uri.path, fragment]
        else
          path_parts = /\A(.*[\/#])([^\/#]+)\Z/.match(uri.path)
          uri.path = path_parts[1]
          [ path_parts[1], path_parts[2] ]
        end
      end

      def make_namespace(namespace_uri)
        candidate = /([^\.]+)(\.[^\.]*)?\Z/.match(namespace_uri.host)[1]
        raise(ArgumentError, "Illegal namespace #{namespace_uri.to_s}") if(candidate.blank?)
        first_candidate = candidate.downcase
        candidate = first_candidate
        counter = 1
        additional_namespaces[candidate.to_sym] ||= namespace_uri.to_s
        while(additional_namespaces[candidate.to_sym] != namespace_uri.to_s)
          counter += 1
          candidate = "#{first_candidate}#{counter}"
          additional_namespaces[candidate.to_sym] ||= namespace_uri.to_s
        end
        candidate
      end

      # Build the structure for the XML file and pass on to
      # the given block
      def build_structure
        @builder.rdf :RDF, namespaces do 
          yield
        end
      end
      
      def additional_namespaces
        @additional_namespaces ||= {}
      end
      
      def namespaces
        namespaces = self.class.namespaces
        additional_namespaces.each { |key, value| namespaces["xmlns:#{key.to_s}"] = value.to_s }
        namespaces
      end

      def self.namespaces
        @namespaces ||= begin
          namespaces = {}
          N::Namespace.shortcuts.each { |key, value| namespaces["xmlns:#{key.to_s}"] = value.to_s }
          namespaces
        end
      end

      # Build an rdf/xml string for one predicate, with the given values
      def write_predicate(predicate, values, check_predicate = true)
        values.each { |val| write_single_predicate(predicate, val, check_predicate) }
      end # end method

      def write_single_predicate(predicate, value, check_predicate = true)
        is_property = value.respond_to?(:uri)
        value_properties = is_property ? { 'value' => value } : extract_values(value.to_s)
        value = value_properties.delete('value')
        predicate_name = predicate.to_name_s
        raise(ArgumentError, "Cannot turn predicate #{predicate} into namespace name") if(check_predicate && (predicate == predicate_name))
        @builder.tag!(predicate.to_name_s, value_properties) do
          if(is_property)
            @builder.rdf :Description, 'rdf:about' => value.uri.to_s
          else
            @builder.text!(value)
          end
        end
      end

      # Splits up the value, extracting encoded language codes and RDF data types. The 
      # result will be returned as a hash, with the "true" value being "value"
      def extract_values(value)
        prop_string = TaliaCore::PropertyString.parse(value)
        result = {}
        result['value'] = prop_string
        result['rdf:datatype'] = prop_string.type if(prop_string.type)
        result['xml:lang'] = prop_string.lang if(prop_string.lang)

        result
      end

    end
  end
end