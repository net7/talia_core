# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaUtil
  module Xml
    # Extends the BaseBuilder to allow for easy writing of xml-rdf data. This can
    # be used in a very self-contained way, by simply passing the triples to write
    # out to the #open_for_triples or #xml_string_for_triples methods. 
    #
    # If those self-contained methods are used the, builder will also "group" the
    # rdf triples, by including all relations for a single subjects in a single tag,
    # etc.
    #
    # Each triple is expected to be an array of 3 elements, for subject, predicate
    # and object. Multiple triples are passed as an array of such arrays.
    #
    # It is also possible to create a builder manually and use the #write_triple
    # inside.
    # 
    # The resulting XML will contain namespace definitions for all namespaces 
    # currently known by N::Namespace. 
    #
    # If the self-contained writer methods is used, it will also build namespace 
    # definitions for all predicates (so that each predicate is expressed as 
    # namespace:name).
    #
    # The namespaces for predicates are not built when using write 
    # methods like write_triple directly. In that case a predicate that is
    # outside a known namespace would cause an invalid xml-rdf, as predicates
    # must not be expressed as full URIs in that format.
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
      
      # Opens a new builder with the given options (see BaseBuilder.open) and
      # writes all the triples given into an xml-rdf document. This will 
      # try to intelligently group the tags to make the result more compact.
      def self.open_for_triples(triples, options = nil)
        my_builder = self.new(options)
        
        triple_hash = my_builder.send(:prepare_triples, triples)
        
        my_builder.send(:build_structure) do
          my_builder.send(:write_for_triples, triple_hash)
        end
      end
      

      # Same as open_for_triples, but writes into a string and returns that
      # string.
      def self.xml_string_for_triples(triples)
        xml = ''
        open_for_triples(triples, :target => xml, :indent => 2)
        xml
      end

      private 
      
      # "Prepares" all the triples into a hash of hashes. This will take the triples
      # and build a hash which has all subjects as keys. The value for each subject
      # will be another hash that has all predicates as keys. The value for each
      # predicate will be an array with all object values for the triple.
      #
      # = Pseudo-Example:
      #  # Input:
      #  [["subject", "predicate1", "value"], ["subject", "predicate2", "value2"], ["subject", "predicate2", "value3"]]
      #  # Output:
      #  {
      #    "subject" => { "predicate1" => ["value", "value2"], "predicate2" => ["value3"] }
      #  }
      #
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
      
      # Special writer that takes a hash of triples that is produced by #prepare_triples
      # and writes it out to the XML document.
      def write_for_triples(triple_hash)
        triple_hash.each do |subject, values|
          @builder.rdf :Description, 'rdf:about' => subject.to_uri.to_name_s do # Element describing this resource
            values.each do |predicate, objects|
              write_predicate(predicate, objects, false)
            end
          end
        end
      end
      
      # This is used to make a namespace for a given predicate. It splits
      # the URI using #split_uri! and passes the "namespace" part of the 
      # URI to #make_namespace to create a symbolic name for it.
      #
      # The method returns the uri of the predicate in a "namespace:local_name"
      # notation.
      def make_predicate_namespace(predicate)
        pred_uri = URI.parse(predicate.to_s)
        path_parts = split_uri!(pred_uri)
        raise(ArgumentError, "Illegal predicate URL #{predicate}") if(path_parts[0].blank? || path_parts[1].blank?)
        namespace = make_namespace(pred_uri)
        "#{namespace}:#{path_parts[1]}"
      end


      # Split a URI into a namespace part and local part. The local part
      # is either the fragment (part after the # character), or the part
      # after the last forward slash.
      #
      # This method needs an URI object from the standard ruby library.
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

      # Create a namespace from a given uri. The method creates a 
      # symbolic name for the namespace from the uri; it will try to
      # create a "readable" result. 
      #
      # The method checks all the previously created namespaces, in case
      # of a name collision, a number is added to the namespace name.
      # 
      # All newly created namespaces are added to a hash that can be
      # accessed with #additional_namespaces
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
      
      # Automatically created namespaces for predicates as a hash. Namespaces
      # are added when they are created using the #make_namespace method.
      def additional_namespaces
        @additional_namespaces ||= {}
      end
      
      # Returns all namespaces configured in N::Namespace and adds the
      # #additional_namespaces to the result
      #
      # Returns a hash where the keys are the xmlns namespace name and the values are
      # the namespace URIs
      def namespaces
        namespaces = self.class.namespaces
        additional_namespaces.each { |key, value| namespaces["xmlns:#{key.to_s}"] = value.to_s }
        namespaces
      end

      # Returns all namespaces configured in N::Namespace
      #
      # Returns a hash where the keys are the xmlns namespace name and the values are
      # the namespace URIs
      def self.namespaces
        @namespaces ||= begin
          namespaces = {}
          N::Namespace.shortcuts.each { |key, value| namespaces["xmlns:#{key.to_s}"] = value.to_s }
          namespaces
        end
      end

      # Build an rdf/xml string for one predicate, with the given values. This is the
      # same as #write_single_predicate for multiple values.
      def write_predicate(predicate, values, check_predicate = true)
        values.each { |val| write_single_predicate(predicate, val, check_predicate) }
      end # end method

      # Writes a single predicate with the given value. When check_predicate is set, this
      # will raise an error if the predicate cannot be represented as "namespace:name"
      def write_single_predicate(predicate, value, check_predicate = true)
        is_property = value.respond_to?(:uri)
        begin # FIXME
          value_properties = is_property ? { 'value' => value } : extract_values(value)
        rescue
          value_properties = is_property ? { 'value' => value } : extract_values(value.to_s)
        end
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
        prop_string = (value.is_a? TaliaCore::PropertyString) ? value : TaliaCore::PropertyString.parse(value)
        result = {}
        result['value'] = prop_string
        result['rdf:datatype'] = prop_string.type if(prop_string.type)
        result['xml:lang'] = prop_string.lang if(prop_string.lang)
        result
      end

    end
  end
end
