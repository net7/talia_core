# require 'objectproperties' # Includes the class methods for the object_properties
require 'source_transfer_object'
require 'active_rdf'
require 'semantic_naming'
require 'dummy_handler'
require 'rdf_resource'

module TaliaCore

  # Base class for most sources in the Talia system. The Source class has some
  # additional features over the basic ActiveSource class.
  #
  # Most importantly, it contains the "smart" accessor in the same style as
  # ActiveRDF:
  #
  #  source.rdf::something
  #  => SemanticCollection Wrapper
  #  
  #  # is the same as:
  #  source[N::RDF.something]
  #
  # There are also 
  class Source < ActiveSource
    # FIXME: Remove methods for old admin panel

    # FIXME: Remove workflow?
    has_one :workflow, :class_name => 'TaliaCore::Workflow::Base', :dependent => :destroy

    # The uri will be wrapped into an object
    def uri
      N::URI.new(self[:uri])
    end

    # Indicates if this source belongs to the local store
    def local
      uri.local?
    end

    # Shortcut for assigning the primary_source status
    def primary_source=(value)
      value = value ? 'true' : 'false'
      predicate_set(:talia, :primary_source, value)
    end

    # Indicates if the current source is considered "primary" in the local 
    # library
    def primary_source
      predicate(:talia, :primary_source) == true
    end

    # Searches for sources where <tt>property</tt> has one of the values given
    # to this method. The result is a hash that contains one result list for
    # each of the values, with the value as a key.
    # 
    # This performs a find operation for each value, and the params passed
    # to this method are added to the find parameters for each of those finds.
    #
    # *Example*
    #  
    #  # Returns all Sources that are of the RDFS type Class or Property. This
    #  # will return a hash with 2 lists (one for the Classes, and one for the
    #  # properties, and each list will be limited to 5 elements.
    #  Source.groups_by_property(N::RDF::type, [N::RDFS.Class, N::RDFS.Property], :limit => 5)
    def self.groups_by_property(property, values, params = {})
      # First create the joins
      joins = 'LEFT JOIN semantic_relations ON semantic_relations.subject_id = active_sources.id '
      joins << "LEFT JOIN active_sources AS t_sources ON semantic_relations.object_id = t_sources.id AND semantic_relations.object_type = 'TaliaCore::ActiveSource' "
      joins << "LEFT JOIN semantic_properties ON semantic_relations.object_id = semantic_properties.id AND semantic_relations.object_type = 'TaliaCore::SemanticProperty' "

      property = uri_string_for(property, false)
      results = {}
      for val in values
        find(:all )
        val_str = uri_string_for(val, false)
        find_parms = params.merge(
        :conditions => ['semantic_properties.value = ? OR t_sources.uri = ?', val_str, val_str],
        :joins => joins
        )
        results[val] = find(:all, find_parms)
      end

      results
    end

    # Try to find a source for the given uri, if not exists it instantiate
    # a new one, combining the N::LOCAL namespace and the given local name
    #
    # Example:
    #   ActiveSource.find_or_instantiate_by_uri('http://talia.org/existent')
    #     # => #<TaliaCore::ActiveSource id: 1, uri: "http://talia.org/existent">
    #
    #   ActiveSource.find_or_instantiate_by_uri('http://talia.org/unexistent', 'Foo Bar')
    #     # => #<TaliaCore::ActiveSource id: nil, uri: "http://talia.org/Foo_Bar">
    #
    # TODO: Delete this/old backend method?
    def self.find_or_instantiate_by_uri(uri, local_name) # :nodoc: 
      result = find_by_uri(uri)
      result ||= self.new(N::LOCAL.to_s + local_name.to_permalink)
    end

    # Return an hash of direct predicates, grouped by namespace.
    # TODO: Delete this/old backend method?
    def grouped_direct_predicates # :nodoc:
      #TODO should it be memoized?
      direct_predicates.inject({}) do |result, predicate|
        predicates = self[predicate].collect { |p| SourceTransferObject.new(p.to_s) }
        namespace = predicate.namespace.to_s
        result[namespace] ||= {}
        result[namespace][predicate.local_name] ||= []
        result[namespace][predicate.local_name] << predicates
        result
      end
    end

    # TODO: Delete this/old backend method?
    def predicate_objects(namespace, name) #:nodoc:
      predicate(namespace, name).values.flatten.map(&:to_s)
    end

    # Check if the current source is related with the given rdf object (triple endpoint).
    # TODO: Delete this/old backend method?
    def associated?(namespace, name, stringified_predicate) # :nodoc:
      predicate_objects(namespace, name).include?(stringified_predicate)
    end

    # Check if a predicate is changed. TODO: Delete this/old backend method?
    def predicate_changed?(namespace, name, objects) # :nodoc:
      not predicate_objects(namespace, name).eql?(objects.map(&:to_s))
    end

    # TODO: Delete this/old backend method?
    attr_reader :predicates_attributes # :nodoc:
    def predicates_attributes=(predicates_attributes) # :nodoc:
      @predicates_attributes = predicates_attributes.collect do |attributes_hash|
        attributes_hash['object'] = instantiate_source_or_rdf_object(attributes_hash)
        attributes_hash
      end
    end

    # Return an hash of new predicated attributes, grouped by namespace.
    # TODO: Delete this/old backend method?
    def grouped_predicates_attributes # :nodoc:
      @grouped_predicates_attributes ||= predicates_attributes.inject({}) do |result, predicate|
        namespace, name = predicate['namespace'], predicate['name']
        predicate = SourceTransferObject.new(predicate['titleized'])
        result[namespace] ||= {}
        result[namespace][name] ||= []
        result[namespace][name] << predicate
        result
      end
    end

      # Save, associate/disassociate given predicates attributes. TODO: Delete this/
      # old backend method?
      def save_predicates_attributes # :nodoc:
        each_predicate do |namespace, name, objects|
          objects.each { |object| object.save if object.is_a?(Source) && object.new_record? }
          self.predicate_replace(namespace, name, objects.to_s) if predicate_changed?(namespace, name, objects)
        end
      end


      # Returns an array of labels for this source. You may give the name of the
      # property that is used as a label, by default it uses rdf:label(s). If
      # the given property is not set, it will return the local part of this
      # Source's URI.
      #
      # In any case, the result will always be an Array with at least one elment.
      def labels(type = N::RDFS::label)
        labels = get_attribute(type)
        unless(labels && labels.size > 0)
          labels = [uri.local_name]
        end

        labels
      end

      # This returns a single label of the given type. (If multiple labels
      # exist in the RDF, just the first is returned.)
      def label(type = N::RDFS::label)
        labels(type)[0]
      end

      # Return the titleized uri local name.
      #
      #   http://localnode.org/source # => Source
      def titleized
        self.uri.local_name.titleize
      end

      # Equality test. Two sources are equal if they have the same URI
      def ==(value)
        value.is_a?(Source) && (value.uri == uri)
      end

      # See Source.normalize_uri
      def normalize_uri(uri, label = '')
        self.class.normalize_uri(uri, label)
      end

      # Returns the Collection (or collections) this source is in.
      def collections
        Collection.find(:all, :find_through => [N::DCT.hasPart, self])
      end

      protected

      # Look at the given attributes and choose to instantiate
      # a Source or a RDF object (triple endpoint).
      #
      # Cases:
      #   Homer Simpson
      #     # => Should instantiate a source with
      #     http://localnode.org/Homer_Simpson using N::LOCAL constant.
      #
      #   "Homer Simpson"
      #     # => Should return the string itself, without the double quoting
      #     in order to add it directly to the RDF triple.
      #
      #   http://springfield.org/Homer_Simpson
      #     # => Should instantiate a source with the given uri
      #
      # TODO: Delete this/old backend method?
      def instantiate_source_or_rdf_object(attributes) # :nodoc:
        name_or_uri = attributes['titleized']
        if /^\"[\w\s\d]+\"$/.match name_or_uri
          name_or_uri[1..-2]
        elsif attributes['uri'].blank? and attributes['source'].blank?
          name_or_uri
        elsif /^http:\/\//.match name_or_uri
          Source.new(name_or_uri)
        else
          Source.find_or_instantiate_by_uri(normalize_uri(attributes['uri']), name_or_uri)
        end
      end

      # Iterate through grouped_predicates_attributes, yielding the given code.
      # TODO: Delete this/old backend method?
      def each_predicate(&block) # :nodoc:
        grouped_predicates_attributes.each do |namespace, predicates|
          predicates.each do |predicate, objects|
            block.call(namespace, predicate, objects.flatten)
          end
        end
      end

      # Class methods
      class << self

        # Normalize the given uri.
        #
        # Example:
        #   normalize_uri('Lucca') # => http://www.talia.discovery-project.org/sources/Lucca
        #   normalize_uri('http://xmlns.com/foaf/0.1/Group') # => http://xmlns.com/foaf/0.1/Group
        #   normalize_uri('http://www.talia.discovery-project.org/sources/Lucca')
        #     # => http://www.talia.discovery-project.org/sources/Lucca
        def normalize_uri(uri, label = '')
          uri = N::LOCAL if uri.blank?
          uri = N::LOCAL+label.gsub(' ', '_') if uri == N::LOCAL.to_s
          uri.to_s
        end

      end

      # End of class methods


      # Missing methods: This just check if the given method corresponds to a
      # registered namespace. If yes, this will return a DummyHandler that
      # allows access to properties.
      # 
      # This will allow invocations such as namespace::name
      def method_missing(method_name, *args)
        # TODO: Add permission checking for all updates to the model
        # TODO: Add permission checking for read access?

        update = method_name.to_s[-1..-1] == '='

        shortcut = if update 
          method_name.to_s[0..-2]
        else
          method_name.to_s
        end

        # Otherwise, check for the RDF predicate
        registered = N::URI[shortcut.to_s]

        return super(method_name, *args) unless(registered) # normal handler if not a registered uri
        raise(ArgumentError, "Must give a namspace as argument") unless(registered.is_a?(N::Namespace))

        DummyHandler.new(registered, self)
      end

    end
  end