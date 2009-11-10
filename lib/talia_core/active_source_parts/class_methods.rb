module TaliaCore
  module ActiveSourceParts
    module ClassMethods

      # Accessor for addtional rdf types that will automatically be added to each
      # object of that Source class
      def additional_rdf_types 
        @additional_rdf_types ||= []
      end

      # New method for ActiveSources. If a URL of an existing Source is given as the only parameter, 
      # that source will be returned. This makes the class work smoothly with our ActiveRDF version
      # query interface.
      #
      # Note that any semantic properties that were passed in to the constructor will be assigned
      # *after* the ActiveRecord "create" callbacks have been called.
      #
      # The option hash may contain a "files" option, which can be used to add data files directly
      # on creation. This will call the attach_files method on the object.
      def new(*args)
        the_source = if((args.size == 1) && (args.first.is_a?(Hash)))
          options = args.first
          options.to_options!

          # We have an option hash to init the source
          files = options.delete(:files)
          options[:uri] = uri_string_for(options[:uri])
          attributes = split_attribute_hash(options)
          the_source = super(attributes[:db_attributes])
          the_source.add_semantic_attributes(false, attributes[:semantic_attributes])
          the_source.attach_files(files) if(files)
          the_source
        elsif(args.size == 1 && ( uri_s = uri_string_for(args[0]))) # One string argument should be the uri
          # Either the current object from the db, or a new one if it doesn't exist in the db
          find(:first, :conditions => { :uri => uri_s } ) || super(:uri => uri_s)
        else
          # In this case, it's a generic "new" call
          super
        end
        the_source.add_additional_rdf_types if(the_source.new_record?)
        the_source
      end

      # Retrieves a new source with the given type. This gets a propety hash
      # like #new, but it will correctly initialize a source of the type given
      # in the hash. If no type is given, this will create a plain ActiveSource.
      def create_source(args)
        args.to_options!
        type = args.delete(:type) || 'TaliaCore::ActiveSource'
        klass = type.constantize
        klass.new(args)
      end

      # Create sources from XML. The result is either a single source or an Array
      # of sources, depending on wether the XML contains multiple sources.
      #
      # The imported sources will be saved during import, to ensure that relations
      # between them are resolved correctly. If one of the imported elements
      # does already exist, the existing source will be rewritten using ActiveSource#rewrite_attributes
      #
      # The options may contain:
      #
      # [*reader*] The reader class that the import should use
      # [*progressor*] The progress reporting object, which must respond to run_with_progress(message, size, &block)
      # [*errors*] If given, all erors will be looged to this array instead of raising
      #            an exception
      # [*duplicates*] How to treat alredy existing sources. See ImportJobHelper for more
      #                documentation
      def create_from_xml(xml, options = {})
        options.to_options!
        reader = options[:reader] ? options[:reader].to_s.classify.constantize : TaliaCore::ActiveSourceParts::Xml::SourceReader
        source_properties = reader.sources_from(xml, options[:progressor], options[:base_file_uri])
        self.progressor = options[:progressor]
        sources = create_multi_from(source_properties, options)
        (sources.size > 1) ? sources : sources.first
      end

      # Creates multiple sources from the given array of attribute hashes. The
      # sources are saved during import, ensuring that the relations are resolved
      # correctly.
      #
      # Options:
      # [*errors*] If given, all erors will be looged to this array instead of raising
      #            an exception
      # [*duplicates*] Indicates how to deal with sources that already exist in the
      #                datastore. See the ImportJobHelper class for a documentation of
      #                this option. Default is :skip
      def create_multi_from(sources, options = {})
        options.to_options!
        source_objects = []
        run_with_progress('Writing imported', sources.size) do |progress|
          source_objects = sources.collect do |props|
            props.to_options!
            src = nil
            begin
              props[:uri] = uri_string_for(props[:uri])
              assit(props[:uri], "Must have a valid uri at this step")
              if(src = ActiveSource.find(:first, :conditions => { :uri => props[:uri] }))
                src.update_source(props, options[:duplicates])
              else
                src = ActiveSource.create_source(props)
              end
              src.save!
            rescue Exception => e
              if(options[:errors]) 
                options[:errors] << "ERROR during import of #{props[:uri]}: #{e.message}" 
                TaliaCore.logger.warn("Problems importing #{props[:uri]} (logged): #{e.message}")
              else
                raise
              end
            end
            progress.inc
            src
          end
        end
        source_objects
      end

      # This method is slightly expanded to allow passing uris and uri objects
      # as an "id"
      def exists?(value)
        if(uri_s = uri_string_for(value))
          super(:uri => uri_s)
        else
          super
        end
      end

      # Semantic version of ActiveRecord::Base#update - the id may be a record id or an URL,
      # and the attributes may contain semantic attributes. See the update_attributes method
      # for details on how the semantic attributes behave.
      def update(id, attributes)
        record = find(id)
        raise(ActiveRecord::RecordNotFound) unless(record)
        record.update_attributes(attributes)
      end

      # Like update, only that it will overwrite the given attributes instead
      # of adding to them
      def rewrite(id, attributes)
        record = find(id)
        raise(ActiveRecord::RecordNotFound) unless(record)
        record.rewrite_attributes(attributes)
      end

      # The pagination will also use the prepare_options! to have access to the
      # advanced finder options
      def paginate(*args)
        prepare_options!(args.last) if(args.last.is_a?(Hash))
        super
      end

      # If will return itself unless the value is a SemanticProperty, in which
      # case it will return the property's value.
      def value_for(thing)
        thing.is_a?(SemanticProperty) ? thing.value : thing
      end

      # Returns true if the given attribute is one that is stored in the database
      def db_attr?(attribute)
        db_attributes.include?(attribute.to_s)
      end

      # Tries to expand a generic URI value that is either given as a full URL
      # or a namespace:name value.
      #
      # This will assume a full URL if it finds a ":/" string inside the URI. 
      # Otherwise it will construct a namespace - name URI
      def expand_uri(uri) # TODO: Merge with uri_for ?
        assit_block do |errors| 
          unless(uri.respond_to?(:uri) || uri.kind_of?(String)) || uri.kind_of?(Symbol)
            errors << "Found strange object of type #{uri.class}"
          end
          true
        end
        uri = uri.respond_to?(:uri) ? uri.uri.to_s : uri.to_s
        return uri if(uri.include?(':/'))
        N::URI.make_uri(uri).to_s
      end

      # Splits the attribute hash that is given for new, update and the like. This
      # will return another hash, where result[:db_attributes] will contain the
      # hash of the database attributes while result[:semantic_attributes] will
      # contain the other attributes. 
      #
      # The semantic attributes will be expanded to full URIs whereever possible.
      #
      # This method will *not* check for attributes that correspond to singular
      # property names.
      def split_attribute_hash(attributes)
        assit_kind_of(Hash, attributes)
        db_attributes = {}
        semantic_attributes = {}
        attributes.each do |field, value|
          if(db_attr?(field))
            db_attributes[field] = value
          else
            semantic_attributes[expand_uri(field)] = value
          end
        end
        { :semantic_attributes => semantic_attributes, :db_attributes => db_attributes }
      end

      private

      # The attributes stored in the database
      def db_attributes
        @db_attributes ||attrs = (ActiveSource.new.attribute_names << 'id')
      end

      # Helper to define a "additional type" in subclasses which will 
      # automatically be added on Object creation
      def has_rdf_type(*types)
        @additional_rdf_types ||= []
        types.each { |t| @additional_rdf_types << t.to_s }
      end

      # Helper to define a "singular accessor" for something (e.g. siglum, catalog)
      # This accessor will provide an "accessor" method that returns the
      # single property value directly and an assignment method that replaces
      # the property with the value.
      #
      # The Source will cache newly set singular properties internally, so that
      # the new value is immediately reflected on the object. However, the
      # change will only be made permanent on #save! - and saving will also clear
      # the cache
      def singular_property(prop_name, property)
        prop_name = prop_name.to_s
        @singular_props ||= []
        return if(@singular_props.include?(prop_name))
        raise(ArgumentError, "Cannot overwrite method #{prop_name}") if(self.instance_methods.include?(prop_name) || self.instance_methods.include?("#{prop_name}="))
        # define the accessor
        define_method(prop_name) do
          prop = self[property]
          assit_block { |err| (prop.size > 1) ? err << "Must have at most 1 value for singular property #{prop_name} on #{self.uri}. Values #{self[property]}" : true }
          prop.size > 0 ? prop[0] : nil
        end

        # define the writer
        define_method("#{prop_name}=") do |value|
          prop = self[property]
          prop.remove
          prop << value
        end

        # define the finder
        (class << self ; self; end).module_eval do
          define_method("find_by_#{prop_name}") do |value, *optional|
            raise(ArgumentError, "Too many options") if(optional.size > 1)
            options = optional.last || {}
            finder = options.merge( :find_through => [property, value] )
            find(:all, finder)
          end
        end

        @singular_props << prop_name
        true
      end

      # Helper to creat an accessor for the given predicate. This will shortcut
      # the prop_name method to self[property]
      def simple_property(prop_name, property)
        define_method(prop_name) do
          self[property]
        end
      end

      # This gets the URI string from the given value. This will just return
      # the value if it's a string. It will return the result of value.uri, if
      # that method exists; otherwise it'll return nil
      def uri_string_for(value)
        result = if value.is_a? String
          return nil if(value  =~ /\A\d+\Z/) # This looks like a record id, encoded as a string
          # if this is a local name, prepend the local namespace
          (value =~ /:/) ? value : (N::LOCAL + value).uri
        elsif(value.respond_to?(:uri))
          value.uri
        else
          nil
        end
        result = result.to_s if result
        result
      end

    end
  end
end