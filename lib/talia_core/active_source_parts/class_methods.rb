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
          if(autofill_overwrites?)
            options[:uri] = auto_uri
          elsif(autofill_uri?)
            options[:uri] ||= auto_uri
          end
          attributes = split_attribute_hash(options)
          the_source = super(attributes[:db_attributes])
          the_source.add_semantic_attributes(false, attributes[:semantic_attributes])
          the_source.attach_files(files) if(files)
          the_source
        elsif(args.size == 1 && ( uri_s = uri_string_for(args[0]))) # One string argument should be the uri
          # Either the current object from the db, or a new one if it doesn't exist in the db
          find(:first, :conditions => { :uri => uri_s } ) || super(:uri => uri_s)
        elsif(args.size == 0 && autofill_uri?)
          auto = auto_uri
          raise(ArgumentError, "Record already exists #{auto}") if(ActiveSource.exists?(auto))
          super(:uri => auto)
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
      #            an exception. See the create_multi_from method for more.
      # [*duplicates*] How to treat alredy existing sources. See ImportJobHelper for more
      #                documentation
      # [*base_file_uri*] The base uri to import file from
      def create_from_xml(xml, options = {})
        options.to_options!
        options.assert_valid_keys(:reader, :progressor, :errors, :duplicates, :base_file_uri)
        reader = options[:reader] ? options.delete(:reader).to_s.classify.constantize : TaliaCore::ActiveSourceParts::Xml::SourceReader
        source_properties = reader.sources_from(xml, options[:progressor], options.delete(:base_file_uri))
        self.progressor = options.delete(:progressor)
        sources = create_multi_from(source_properties, options)
        (sources.size > 1) ? sources : sources.first
      end

      # Creates multiple sources from the given array of attribute hashes. The
      # sources are saved during import, ensuring that the relations are resolved
      # correctly.
      #
      # Options:
      # [*errors*] If given, all erors will be logged to this array instead of raising
      #            an exception. Each "entry" in the error array will be an Error object
      #            containing the origianl stack trace of the error
      # [*duplicates*] Indicates how to deal with sources that already exist in the
      #                datastore. See the ImportJobHelper class for a documentation of
      #                this option. Default is :skip
      def create_multi_from(sources, options = {})
        options.to_options!
        options.assert_valid_keys(:errors, :duplicates)
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
                err = ImportError.new("ERROR during import of #{props[:uri]}: #{e.message}")
                err.set_backtrace(e.backtrace)
                options[:errors] <<  err
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
          elsif(defined_property?(field))
            semantic_attributes[field] = value
          else
            semantic_attributes[expand_uri(field)] = value
          end
        end
        { :semantic_attributes => semantic_attributes, :db_attributes => db_attributes }
      end
      
      def defined_property?(prop_name)
        prop_name = prop_name.to_s
        (@defined_props && @defined_props.include?(prop_name)) || (superclass.respond_to?(:defined_property?) && superclass.defined_property?(prop_name))
      end

      def props_to_destroy
        @props_to_destroy ||= []
      end

      private
      
      # Make URL for autofilling
      def auto_uri
        (N::LOCAL + self.name.tableize + "/#{rand Time.now.to_i}").to_s
      end

      # The attributes stored in the database
      def db_attributes
        @db_attributes ||= (ActiveSource.new.attribute_names << 'id')
      end

      # Helper to define a "additional type" in subclasses which will 
      # automatically be added on Object creation
      def has_rdf_type(*types)
        @additional_rdf_types ||= []
        types.each { |t| @additional_rdf_types << t.to_s }
      end
      
      # Class helper to declare that this Source model is allowed to automatically
      # create uri values for new elements. In that case, the model will
      # automatically assign a URL to all new records to which no url value has
      # been passed.
      #
      # If the :force option is set, the autofill will overwrite an existing uri that
      # is passed in during creation.
      def autofill_uri(options = {})
        options.to_options!
        options.assert_valid_keys(:force)
        @can_autofill = true
        @autofill_overwrites = options[:force]
      end
      
      def autofill_uri?
        @can_autofill
      end
      
      def autofill_overwrites?
        @autofill_overwrites
      end

      # Helper to define a "singular accessor" for something (e.g. siglum, catalog)
      # This accessor will provide an "accessor" method that returns the
      # single property value directly and an assignment method that replaces
      # the property with the value.
      #
      # A find_by_<property> finder method is also created.
      #
      # The Source will cache newly set singular properties internally, so that
      # the new value is immediately reflected on the object. However, the
      # change will only be made permanent on #save! - and saving will also clear
      # the cache
      #
      # The options recognized at this time are 
      #  [*:force_relation*] Forces the the values to be relations. This means that
      #                      each and every value passed to the generated accessors
      #                      will be interpreted as a URL. *Issue/Note*: The 
      #                      values will not be forced of you assign using << on the
      #                      multi accessors.
      #  [*:dependent*] You may pass :dependend => :destroy as for ActiveRecord relations
      def singular_property(prop_name, property, options = {})
        define_property(true, prop_name, property, options)
      end
      
      
      # Defines a multi-value property in the same way as #singular_property
      def multi_property(prop_name, property, options = {})
        define_property(false, prop_name, property, options)
      end

      # Defines a "manual" property. This means that getters and setters are provided
      # by the user and this statement only declares that the system may autoassign to
      # that property
      def manual_property(prop_name)
        @defined_props ||= []
        @defined_props << prop_name.to_s
      end

      # Defines a property (multi or single). This makes the property available as a 
      # ActiveRecord-like accessor. See documentation on singular_property
      def define_property(single_access, prop_name, property, options = {}) # :nodoc:
        prop_name = prop_name.to_s
        options.to_options!
        options.assert_valid_keys(:force_relation, :dependent)
        @defined_props ||= []
        @props_to_destroy ||= []
        return if(@defined_props.include?(prop_name))
        raise(ArgumentError, "Cannot overwrite method #{prop_name}") if(self.instance_methods.include?(prop_name) || self.instance_methods.include?("#{prop_name}="))
        
        # define the accessor
        single_access ? define_singular_reader(prop_name, property) : define_multi_reader(prop_name, property)

        # define the writer
        define_writer(single_access, prop_name, property, options)

        # define the finder
        (class << self ; self; end).module_eval do
          define_method("find_by_#{prop_name}") do |value, *optional|
            raise(ArgumentError, "Too many options") if(optional.size > 1)
            options = optional.last || {}
            finder = options.merge( :find_through => [property, value] )
            find(:all, finder)
          end
        end

        @defined_props << prop_name
        @props_to_destroy << prop_name if(options[:dependent] && (options[:dependent].to_sym == :destroy))
        true
      end
      
      
      # Helper to dynamically define the singular accessor
      def define_singular_reader(prop_name, property)
        define_method(prop_name) do
          prop = self[property]
          assit_block { |err| (prop.size > 1) ? err << "Must have at most 1 value for singular property #{prop_name} on #{self.uri}. Values #{self[property]}" : true }
          prop.size > 0 ? prop.first : nil
        end
      end
      
      # Helper to dynamically define the multiple-value accessor
      def define_multi_reader(prop_name, property)
        define_method(prop_name) do
          self[property]
        end
      end
      
      # Helper to dynamically define the singular or multi-value assignment accessor
      def define_writer(singular_access, prop_name, property, options = {})
        force_link = options[:force_relation] || false
        destroy_dependent = (options[:dependent] && (options[:dependent].to_sym == :destroy))
        define_method("#{prop_name}=") do |values|
          values = [ values ] unless(values.is_a?(Array)) 
          raise(ArgumentError, "Must assign a single value here") if(singular_access && (values.size > 1))
          prop = self[property]
          destroy_elements(prop, values) if(destroy_dependent)
          prop.remove
          values.each do |value|
            next if(value.blank?)
            value = ActiveSource.find(value) if(force_link && !value.is_a?(ActiveSource))
            prop << value
          end
        end
      end
      
      # This gets the URI string from the given value. This will just return
      # the value if it's a string. It will return the result of value.uri, if
      # that method exists; otherwise it'll return nil
      def uri_string_for(value)
        result = if value.is_a? String
          return nil if(value  =~ /\A\d+(-.*)?\Z/) # This looks like a record id or record param, encoded as a string
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