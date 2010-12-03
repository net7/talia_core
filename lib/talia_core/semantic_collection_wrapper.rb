# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore

  # Class for the collection of elements returned by the "semantic accessor" methods
  # of a source (e.g. source[N::RDF.somethink])
  #
  # Each wrapper contains the values for one predicate of one source
  # (that is, for all triples of the form <thesource> <thepredicate> ?object). 
  #
  # The wrapper will lazy-load the data and only do a query to the database once
  # the items are actually requested. If a database request is necessary, all data
  # will be fetched in a single request.
  #
  # Modifications of the wrapper will happen in memory. Only when the wrapper is saved
  # using #save_items! will the modifications be written to the data store. 
  # #save_items! will be called by the "owning" source of this wrapper when the source
  # is being saved.
  #
  # Some of the methods work on the _values_, and other on the _objects_ of the 
  # collection. See SemanticCollectionItem#value and SemanticCollectionItem#object for
  # more on that.
  class SemanticCollectionWrapper

    include Enumerable

    attr_reader :force_type

    # Simple hash that checks if a type if property requires "special" handling
    # This will cause the wrapper to accept ActiveSource relations and all
    # sources will be casted to the given type
    def self.special_types
      @special_types ||= {
        N::RDF.type.to_s => N::SourceClass
      }
    end

    # Initialize the collection with the given source and predicate. No database
    # will take place during creation of the object
    def initialize(source, predicate)
      @assoc_source = source
      @assoc_predicate = if(predicate.respond_to?(:uri))
        predicate.uri.to_s
      else
        predicate.to_s
      end
      @force_type = self.class.special_types[@assoc_predicate]
    end

    # Get the element _value_ at the given index. See also
    # SemanticCollectionItem#value
    def at(index)
      items.at(index).value if(items.at(index))
    end
    alias :[] :at

    # The first _value_ in the collection
    def first
      item = items.first
      item ? item.value : nil
    end

    # The last _value_ in the collection
    def last
      item = items.last
      item ? item.value : nil
    end

    # Gets the _object_ at the given index. See 
    # SemanticCollectionItem#object
    def get_item_at(index)
      items.at(index).object if(items.at(index))
    end

    # Iterates over each _value_ of the items in the relation.
    def each
      items.each { |item| yield(item.value) }
    end

    # Collect method for the semantic wrapper, iterating
    # over the _values_ of the collection
    def collect
      items.collect { |item| yield(item.value) }
    end

    # Iterates of each _object_ of the items in the relation. 
    def each_item
      items.each { |item| yield(item.object) }
    end

    # Returns an array with all _values_ in the collection
    def values
      items.collect { |item| item.value }
    end

    # Returns only the _values_ of the given language.
    # (At the moment this is not aware of region codes or any
    # specialities, it just does a string matching)
    #
    # If no values with the given locale are found, this will
    # fall back on the default locale and then to the values
    # that don't have a locale at all.
    def values_with_lang(language = 'en')
      language_is_default = (language == I18n.default_locale.to_s)
      real = []
      default = []
      unset = []
      items.each do |item|
        # FIXME: At the moment, this only works for value attributes, not for 
        # sources
        if((val = item.value).respond_to?(:lang))
          real << val if(val.lang == language)
          default << val if(!language_is_default && (val.lang == I18n.default_locale.to_s))
          unset << val if(val.lang.blank?)
        else
          default << val
        end
      end
      return real unless(real.empty?)
      return default unless(default.empty?)
      unset
    end
    
    # Size of the collection
    def size
      return items.size if(loaded?)
      if(@items)
        # This is not really possible without loading, so we do it
        load!
        items.size
      else
        SemanticRelation.count(:conditions => {
          'subject_id' => @assoc_source.id,
          'predicate_uri' => @assoc_predicate })
        end
      end

      # Joins the _values_ of the colle ction into a string
      def join(join_str = ', ')
        strs = items.collect { |item| item.value.to_s }
        strs.join(join_str)
      end

      # Index of the given _value_
      def index(value)
        items.index(value)
      end

      # Check if the collection includes the _value_ given
      def include?(value)
        items.include?(value)
      end
      
      # Creates a record for a value and adds it. This will add the given value if it is
      # a database record and otherwise create a property with the given value.
      #
      # If a block is given, it will be called with the new element after the new element
      # has been added to the collection. If value is a collection, the block will be
      # called for each element of the collection.
      #
      # The order, if not nil, can be used to have a fixed order of SemanticRelation
      # records. This is mainly used by the Collection class
      def add_record(value, order = nil)
        raise(ArgumentError, "Blank value assigned") if(value.blank? && !value.is_a?(Enumerable))
        # We use order exclusively for "ordering" predicates
        assit_equal(TaliaCore::Collection.index_to_predicate(order), @assoc_predicate) if(order)

        value = [ value ] unless(value.kind_of?(Array))

        value.each do |val|
          rel = create_predicate(val)
          rel.rel_order = order if(order)
          block_given? ? yield(rel) : insert_item(rel)
        end
      end
      alias_method '<<', :add_record
      alias_method :concat, :add_record

      # Replace a value with a new one. Equivalent to removing the old value
      # and adding the new one
      def replace_value(old_value, new_value)
        idx = items.index(old_value)
        items[idx].destroy
        # Creates a new relation and adds it in the place of the old one
        add_record(new_value) { |new_item| items[idx] = new_item }
      end
      
      # Replace the contents of the current wrapper with the values passed. 
      # Blank values are ignored by this method. If non new values are passed 
      # (or all values are blank), this will simply 
      def replace(*new_values)
        new_values.flatten! if(new_values.first.is_a?(Array)) # Flatten if used as #replace([a, b, c])
        new_values.reject! { |v| v.blank? }
        new_values.collect! { |v| create_predicate(v) }
        remaining_items = []      
        items.each do |item|
          if(new_values.include?(item))
            remaining_items << item
            new_values.delete(item)
          else
            item.destroy
          end
        end
        @items = remaining_items + new_values
      end

      # Remove the given value. With no parameters, the whole list will be
      # cleared and the RDF will be updated immediately (!).
      def remove(*params)
        if(params.length > 0)
          params.each { |par| remove_relation(par) }
        else
          if(loaded?)
            items.each { |item| item.destroy }
          else
            SemanticRelation.destroy_all(
            :subject_id => @assoc_source.id,
            :predicate_uri => @assoc_predicate
            )
          end
          @assoc_source.my_rdf.remove(@assoc_predicate.to_uri) unless(@assoc_source.uri.to_s.blank?)
          @items = []
          @loaded = true
        end
      end

      # This attempts to save the items to the database. This will do nothing if
      # the collection was never loaded to memory. It also tries to ignore data
      # that is known to already exist in the data store and only write the records
      # could actually have been modified.
      def save_items!
        return if(clean?) # If there are no items, nothing was modified
        @assoc_source.save! unless(@assoc_source.id)
        @items.each do |item|
          item.save!
        end
        @items = nil unless(loaded?) # Otherwise we'll have trouble reload-and merging
      end

      # Indicates of the internal collection is loaded
      def loaded?
        @loaded
      end

      # Indicates that the wraper is "clean", that is it hasn't been written to
      # or read from
      def clean?
        @items.nil?
      end

      def empty?
        self.size == 0
      end
      
      # Forces this relation to be empty. This initializes the relation,
      # assuming that no data exists in the database. The collection will
      # be empty, and the database will *not* be queried.
      #
      # *Warning* Only call this if you need an empty wrapper
      # and you are sure that there are no corresponding values in the database
      def init_as_empty!
        raise(ArgumentError, "Already initialized!") if(loaded?)
        @items = []
        @loaded = true
      end

      # Insert a new relation directly. To be used with care!
      def insert_item(item) # :nodoc:
        raise(ArgumentError, "Can only insert a SemanticRelation") unless(item.is_a?(SemanticRelation))
        raise(ArgumentError, "New relation does not match the predicate of the wrapper") if(item.predicate_uri != @assoc_predicate.to_s)
        @items ||= []
        @items << item
      end

      private

      # Load the current collection from the database.
      def load!
        # Check if there are records that have been added previously
        relations = SemanticRelation.find(:all, 
          :conditions => { :subject_id => @assoc_source.id, :predicate_uri => @assoc_predicate.to_s }, 
          :include => [:subject, :object])
        @items ||= []
        @loaded = true
        @items = (relations | @items)
      end

      # Returns the items in the collection. These are the SemanticCollectionItem
      # objects
      def items
        load! unless(loaded?)
        @items
      end

      # Deletes the relation where with the current predicate and the given 
      # value.
      def remove_relation(value)
        idx = items.index(value)
        return unless(idx)
        remove_at(idx)
      end

      # Removes a relation at the given index
      def remove_at(index)
        items.at(index).destroy
        items.delete_at(index)
      end

      # Creates a new semantic relation with the given value and the subject
      # and predicate taken from the collection. The value will be converted
      # into an ActiveSource or SemanticProperty as appropriate and used as
      # the object of the new SemanticRelation
      def create_predicate(value)
        # TODO: Semantic Properties should only be created inside, since assigning
        #       one to multiple relations and then deleting breaks integrity.
        #       The whole semantic property should be flattened into a field in
        #       SemanticRelation anyway.
        assit(!value.is_a?(SemanticProperty), "Should not pass in Semantic Properties here!")
        # We need to manually create the relation, to add the predicate_url
        to_add = SemanticRelation.new(
        :subject => @assoc_source,
        :predicate_uri => @assoc_predicate, 
        :object => create_object_value(value)
        ) 
      end
      
      # Creates the "object value" which, for the given value, will be used as
      # the object for the SemanticRelation.
      def create_object_value(value)
        if(@force_type)
          # If we have the "force_type" option, we assume that every value
          # we get is a Resource/ActiveSource
          uri = value.respond_to?(:uri) ? value.uri : value
          ActiveSource.new(uri.to_s)
        elsif(value.is_a?(TaliaCore::ActiveSource) || value.is_a?(TaliaCore::SemanticProperty))
          value
        elsif(value.respond_to?(:uri)) # This appears to refer to a Source. We only add if we can find that source
          TaliaCore::ActiveSource.find(value.uri)
        elsif(prop_options[:type].is_a?(Class) && (prop_options[:type] <= TaliaCore::ActiveSource))
          TaliaCore::ActiveSource.find(value)
        else
          # Check if we need to add from a PropertyString
          propvalue = value.is_a?(PropertyString) ? value.to_rdf : value
          TaliaCore::SemanticProperty.new(:value => propvalue)
        end
      end
      
      # The options that were defined on the "owning" source with
      # singular_property, multi_property or property_options
      def prop_options
        @assoc_source.property_options_for(@assoc_predicate)
      end

    end

  end
