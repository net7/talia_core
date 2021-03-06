# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  
  # This class encapsulate the basic "Source" behaviour for an element in the
  # semantic store. This is the baseclass for all things that are represented
  # as an "Resource" (with URL) in the semantic store.
  #
  # If an object is modified but <b>not</b> saved, the ActiveSource does <b>not</b>
  # guarantee that the RDF will always be in sync with the database. However,
  # a subsequent saving of the object will re-sync the RDF.
  #
  # An effort is made to treat RDF and database writes in the same way, so that
  # they should <i>usually</i> be in sync:
  #
  # * Write operations are usually lazy, the data should only be saved once
  #   save! is called. However, ActiveRecord may still decide that the objects
  #   need to be saved if they are involved in other operations.
  # * Operations that clear a predicate are <b>immediate</b>. That also means
  #   that using singular property setter, if
  #   used will immediately erase the old value. If the record is not saved,
  #   the property will be left empty (and not revert to the original value!)
  class ActiveSource < ActiveRecord::Base
    
    # Act like an ActiveRdfResource
    include ActiveRDF::ResourceLike
    
    extend ActiveSourceParts::ClassMethods
    extend ActiveSourceParts::Finders
    extend ActiveSourceParts::SqlHelper
    include ActiveSourceParts::PredicateHandler
    extend ActiveSourceParts::PredicateHandler::ClassMethods
    include ActiveSourceParts::RdfHandler
    extend TaliaUtil::Progressable # Progress for import methods on class
    
    # Set the handlers for the callbacks defined in the other modules. The
    # order matters here.
    after_update :auto_update_rdf
    after_create :auto_create_rdf
    after_save :save_wrappers # Save the cache wrappers
    before_destroy :destroy_dependent_props
    after_destroy :clear_rdf

    
    # Relations where this source is the subject of the triple
    has_many :semantic_relations, :foreign_key => 'subject_id', :class_name => 'TaliaCore::SemanticRelation', :dependent => :destroy
    
    # Data records attached to the active source
    has_many :data_records, :class_name => 'TaliaCore::DataTypes::DataRecord', :dependent => :destroy, :foreign_key => 'source_id'
           
    # Relations where this source is the object of the relation
    has_many :related_subjects,
      :foreign_key => 'object_id',
      :class_name => 'TaliaCore::SemanticRelation'
    has_many :subjects, :through => :related_subjects
    
    validates_format_of :uri, :with => /\A\S*:.*\Z/, :message => '<{{value}}> does not look like an uri.'
    validates_uniqueness_of :uri

    before_destroy :remove_inverse_properties # Remove inverse properties when destroying an element

    # We may wish to use the following Regexp.
    # It matches:
    #   http://discovery-project.eu
    #   http://www.discovery-project.eu
    #   http://trac.talia.discovery-project.eu
    #   http://trac.talia.discovery-project.eu/source
    #   http://trac.talia.discovery-project.eu/namespace#predicate
    #
    # validates_format_of :uri,
    #   :with => /^(http|https):\/\/[a-z0-9\_\-\.]*[a-z0-9_-]{1,}\.[a-z]{2,4}[\/\w\d\_\-\.\?\&\#]*$/i
    
    validate :check_uri    

    # Uri in short notation
    def short_uri
      N::URI.new(self.uri).to_name_s
    end

    # Helper
    def value_for(thing)
      self.class.value_for(thing)
    end

    # To string: Just return the URI. Use to_xml if you need something more
    # involved.
    def to_s
      self[:uri]
    end
    
    # Create a new uri object
    def to_uri
      self[:uri].to_uri
    end

    # Works in the normal way for database attributes. If the value
    # is not an attribute, it tries to find objects related to this source
    # with the value as a predicate URL and returns a collection of those.
    #
    # The assignment operator remains as it is for the ActiveRecord.
    def [](attribute)
      if(db_attr?(attribute))
        super(attribute)
      elsif(defined_property?(attribute))
        self.send(attribute)
      else
        get_objects_on(attribute)
      end
    end
    alias :get_attribute :[]

    # Assignment to an attribute. This will overwrite all current triples.
    def []=(attribute, value)
      if(db_attr?(attribute))
        super(attribute, value)
      elsif(defined_property?(attribute))
        self.send("#{attribute}=", value)
      else
         get_wrapper_on(attribute).replace(value)
      end
    end

    # Make aliases for the original updating methods
    alias :update_attributes_orig :update_attributes
    alias :update_attributes_orig! :update_attributes!


    # Updates the source with the given properties. The 'mode' field indicates if
    # and how the update will be performed. See the ImportJobHelper class for
    # the different modes.
    #
    # As opposed to the *_attributes method, this will also handle file elements.
    # The default mode is :skip (do nothing)
    def update_source(properties, mode)
      properties.to_options!
      mode = :update if(self.is_a?(SourceTypes::DummySource)) # Dummy sources are always updated
      mode ||= :skip
      mode = mode.to_sym
      return self if(mode == :skip) # If we're told to ignore updates
      
      # Deal with already existing sources
      files = properties.delete(:files)
      
      if(mode == :overwrite)
        # If we are to overwrite, delete all relations and update normally
        self.semantic_relations.destroy_all
        self.data_records.destroy_all
        mode = :update
      elsif(mode == :update && files && self.data_records.size > 0)
        # On updating we should only remove the files if there are new ones
        self.data_records.destroy_all
      end
      
      # Add any files
      attach_files(files) if(files)
      
      # Rewrite the type, if neccessary
      type = properties[:type]
      switch_type = type && (self.type != type)
      # Warn to the log if we have a problematic type change
      TaliaCore.logger.warn("WARNING: Type change from #{self.type} to #{type}") if(switch_type && !self.is_a?(SourceTypes::DummySource))
      self.type = type if(switch_type)
      
      # Now we should either be adding or updating
      assit(mode == :update || mode == :add)
      update = (mode == :update)
      
      # Overwrite with or add the imported attributes
      update ? rewrite_attributes(properties) : update_attributes(properties)
      
      self
    end

    # Updates *all* attributes of this source. For the database attributes, this works
    # exactly like ActiveRecord::Base#update_attributes
    #
    # If semantic attributes are present, they will be updated on the semantic store.
    #
    # After the update, the source will be saved.
    def update_attributes(attributes)
      yield self if(block_given?)
      super(process_attributes(false, attributes))
    end

    # As update_attributes, but uses save! to save the source 
    def update_attributes!(attributes)
      yield self if(block_given?)
      super(process_attributes(false, attributes))
    end
    
    # Works like update_attributes, but will replace the semantic attributes
    # rather than adding to them.
    def rewrite_attributes(attributes)
      yield self if(block_given?)
      update_attributes_orig(process_attributes(true, attributes)) 
    end
    
    # Like rewrite_attributes, but calling save!
    def rewrite_attributes!(attributes)
      yield self if(block_given?)
      update_attributes_orig!(process_attributes(true, attributes))
    end
    
    # Helper to update semantic attributes from the given hash. If there is a
    # "<value>" string, it will be treated as a reference to an URI. Hash
    # values may be arrays.
    #
    # If overwrite is set to yes, the given attributes (and only those)
    # are replaced with the values from the hash. Otherwise
    # the attribute values will be added to the existing ones
    def add_semantic_attributes(overwrite, attributes)
      attributes.each do |attr, value|
        if(defined_property?(attr))
          self[attr] = value
        else
          attr_wrap = self[attr]
          attr_wrap.remove if(overwrite)
          value.to_a.each { |val| self[attr] << target_for(val) }
        end
      end
    end

    # Returns a special object which collects the "inverse" properties 
    # of the Source - these are all RDF properties which have the current
    # Source as the object.
    #
    # The returned object supports the [] operator, which allows to fetch the
    # "inverse" (the RDF subjects) for the given predicate.
    #
    # Example: <tt>person.inverse[N::FOO::creator]</tt> would return a list of
    # all the elements of which the current person is the creator.
    def inverse
      inverseobj = Object.new
      inverseobj.instance_variable_set(:@assoc_source, self)
      
      class << inverseobj     
        
        def [](property)
          @assoc_source.subjects.find(:all, :conditions => { 'semantic_relations.predicate_uri' => property.to_s } )
        end
        
        private :type
      end
      
      inverseobj
    end
    
    # Accessor that allows to lookup a namespace/name combination. This works like
    # the [] method: I will return an array-like object on predicates can be
    # manipulated.
    def predicate(namespace, name)
      get_objects_on(get_namespace(namespace, name))
    end
    
    # Setter method for predicates by namespace/name combination. This will 
    # *add a precdicate triple, not replace one!*
    def predicate_set(namespace, name, value)
      predicate(namespace, name) << value
    end
    
    # Setter method that will only add the value if it doesn't exist already
    def predicate_set_uniq(namespace, name, value)
      pred = predicate(namespace, name)
      pred << value unless(pred.include?(value))
    end
    
    # Replaces the given predicate with the value. Good for one-value predicates
    def predicate_replace(namespace, name, value)
      pred = predicate(namespace, name)
      pred.remove
      pred << value
    end
    
    # Gets the direct predicates (using the database)
    def direct_predicates
      raise(ActiveRecord::RecordNotFound, "Cannot do this on unsaved record.") if(new_record?)
      rels = SemanticRelation.find_by_sql("SELECT DISTINCT predicate_uri FROM semantic_relations WHERE subject_id = #{self.id}")
      rels.collect { |rel| N::Predicate.new(rel.predicate_uri) }
    end
    
    # Gets the inverse predicates
    def inverse_predicates
      raise(ActiveRecord::RecordNotFound, "Cannot do this on unsaved record.") if(new_record?)
      rels = SemanticRelation.find_by_sql("SELECT DISTINCT predicate_uri FROM semantic_relations WHERE object_id = #{self.id}")
      rels.collect { |rel| N::Predicate.new(rel.predicate_uri) }
    end
    
    # BY RIK
    # Like #inverse_predicates, except it is a little more informative: for each triple where this object's
    # URI is the object, returns predicate and subject URIs and the subject type.
    def inverse_triples
      raise(ActiveRecord::RecordNotFound, "Cannot do this on unsaved record.") if(new_record?)
      query  = "SELECT * FROM semantic_relations A INNER JOIN active_sources B ON A.subject_id=B.id "
      query << "WHERE A.object_id='#{self.id}';"
      SemanticRelation.find_by_sql(query).collect do |r|
        {
          :subject => r.subject.uri, 
          :subject_class => r.subject.type.constantize,
          :predicate => N::Predicate.new(r.predicate_uri)
        }
      end
    end

    # True if the given attribute is a database attribute
    def db_attr?(attribute)
      ActiveSource.db_attr?(attribute)
    end
    
    def defined_property?(prop_name)
      self.class.defined_property?(prop_name)
    end
    
    def property_options_for(property)
      self.class.property_options_for(property)
    end

    # Writes the predicate directly to the database and the rdf store. The
    # Source does not need to be saved and no data is loaded from the database.
    # This is faster than adding the data normally and doing a full save,
    # at least if only one or two predicates are written.
    def write_predicate_direct(predicate, value)
      autosave = self.autosave_rdf?
      value.save! if(value.is_a?(ActiveSource) && value.new_record?)
      self.autosave_rdf = false
      self[predicate] << value
      uri_res = N::URI.new(predicate)
      # Now add the RDF data by hand
      if(value.kind_of?(Array))
        value.each do |v|
          my_rdf.direct_write_predicate(uri_res, v)
        end
      else
        my_rdf.direct_write_predicate(uri_res, value)
      end
      save! # Save without RDF save
      self.autosave_rdf = autosave
    end


    # XML Representation of the source. The object is saved if this is a new
    # record.
    def to_xml
      save! if(new_record?)
      ActiveSourceParts::Xml::SourceBuilder.build_source(self)
    end

    # Creates an RDF/XML reprentation of the source. The object is saved if
    # this is a new record.
    def to_rdf
      save! if(new_record?)
      ActiveSourceParts::Xml::RdfBuilder.build_source(self) 
    end

    # BY RIK
    #
    # TODO: how to automate "metadata"(4), especially license?
    #
    # Creates a LOD compatible RDF/XML representations of the source.
    # Reference: http://www4.wiwiss.fu-berlin.de/bizer/pub/LinkedDataTutorial/#deref
    # This method will build "backlinks" (2) automatically, and try to deduce
    # "related descriptions" (3) by the model multi_property declarations.
    #
    # Extend this method wherever you need special data treatment. 
    # If you don't want a particular Source type to have a lod representation,
    # Overwrite the class #lod? method and make it return false. This also means that 
    # URIs of sources of that type will never be shown in the backlinks section of another
    # source's rdf.
    #
    # The object is saved if this is a new record.
    def to_lod_rdf(check_predicates=true)
      return '' unless self.class.lod?
      save! if new_record?
      ActiveSourceParts::Xml::LodRdfBuilder.build_source(self, check_predicates)
    end

    # Add the additional types to the source that were configured in the class.
    # Usually this will not need to be called directly, but will be automatically
    # called during construction.
    #
    # This will check the existing types to avoid duplication
    def add_additional_rdf_types
      # return if(self.class.additional_rdf_types.empty?)
      type_hash = {}
      self.types.each { |type| type_hash[type.respond_to?(:uri) ? type.uri.to_s : type.to_s] = true }
      # Add the "class" default type type (unless this is the source for the self type itself).0
      self.types << rdf_selftype unless(type_hash[rdf_selftype.to_s] || (rdf_selftype.to_s == self.uri.to_s))
      # Add the user-configured types
      self.class.additional_rdf_types.each do |type|
        self.types << type unless(type_hash[type.respond_to?(:uri) ? type.uri.to_s : type.to_s])
      end
    end

    # Attaches files from the given hash. See the new method on ActiveSource for the
    # details.
    #
    # The call in this case should look like this:
    #
    #  attach_files([{ url => 'url_or_filename', :options => { .. }}, ...])
    # 
    # Have a look at the DataLoader module to see how the options work. You may also provide
    # a single hash for :files (instead of an array) if you have just one file. Files will
    # be saved immediately.
    def attach_files(files)
      files = [ files ] unless(files.is_a?(Array))
      files.each do |file|
        file.to_options!
        filename = file[:url]
        assit(filename)
        options = file[:options] || {}
        records = DataTypes::FileRecord.create_from_url(filename, options)
        records.each { |rec| self.data_records << rec }
      end
    end
    
    # This will return a list of DataRecord objects. Without parameters, this
    # returns all data elements on the source. If a type is given, it will
    # return only the elements of the given type. If both type and location are
    # given, it will retrieve only the specified data element
    def data(type = nil, location= nil)
      find_type = location ? :first : :all # Find just one element if a location is given
      type = type.name if(type.is_a?(Class))
      options = {}
      options[:conditions] = [ "type = ?", type ] if(type && !location)
      options[:conditions] = [ "type = ? AND location = ?", type, location ] if(type && location)
      data_records.find(find_type, options)
    end
    
    # The RDF type that is used for objects of the current class
    def rdf_selftype
      (N::TALIA + self.class.name.demodulize)
    end

    def reload
      reset! # Clear the property cache
      super
    end

    private
    
    # Removes dependent properties
    def destroy_dependent_props
      self.class.props_to_destroy.each do |prop|
        values = self[prop]
        values = [values] unless(values.is_a?(SemanticCollectionWrapper))
        values.each do |val|
          val.destroy if(val.is_a?(TaliaCore::ActiveSource))
        end
      end
    end
    
    # Extracts the semantic attributes from the attribute hash and passes them
    # to add_semantic_attributes with the given overwrite flag.  
    # The database attributes are returned by the method
    def process_attributes(overwrite, attributes)
      attributes = self.class.split_attribute_hash(attributes)
      add_semantic_attributes(overwrite, attributes[:semantic_attributes])
      attributes[:db_attributes]
    end
    
    # Creates the target for the given attribute. If the value
    # has the format <...>, it will be returned as an URI object, if it's a normal
    # string it will be returned as a string.
    def target_for(value)
      return value if(value.kind_of?(N::URI) || value.kind_of?(ActiveSource))
      assit_block { |msg| msg << "Expected #{value.inspect} to be a String" unless(value.is_a?(String)) ; value.is_a?(String) }
      value.strip!
      if((value[0..0] == '<') && (value[-1..-1] == '>'))
        value = ActiveSource.expand_uri(value [1..-2])
        val_src = ActiveSource.find(:first, :conditions => { :uri => value })
        if(!val_src)
          value = SourceTypes::DummySource.new(value)
          value.save!
        else
          value = val_src
        end
      end
      value
    end

    # Get the namespace URI object for the given namespace
    def get_namespace(namespace, name = '')
      namesp_uri = N::Namespace[namespace]
      raise(ArgumentError, "Illegal namespace given #{namespace}") unless(namesp_uri)
      namesp_uri + name.to_s
    end

    # Takes over the validation for ActiveSources
    def validate
      self.class
    end

    # Check the uri should be different than N::LOCAL, this could happen when an user
    # leaves the input text blank.
    def check_uri
      self.errors.add(:uri, "Cannot be blank") if self.uri == N::LOCAL.to_s
    end

    # Remove the inverse properties, to be called before destroy. Doing this
    # through the polymorphic relation automatically could be a bit fishy...
    def remove_inverse_properties
      SemanticRelation.delete_all(["object_type = 'TaliaCore::ActiveSource' AND object_id = ?", self.id])
    end
    
  end
  
end
