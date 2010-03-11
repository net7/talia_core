module TaliaCore

  # Represents a collection of sources. In addition to being a container for 
  # sources, the Collection class will also provide an ordering of the contained
  # soruces.
  # 
  # The ordering will always assign a ''unique'' integer value to each contained
  # source, that define it's position in the order of elements. (The collection will
  # keep an internal array where each object's index maps directly to its position 
  # in the collection).
  #
  # The collection class is relatively lightweight and will behave mostly like
  # the underlying array.
  #
  # This also means that all checks on added objects will only be performed when
  # the collection is saved, and not much checking is done when the array is
  # modified.
  #
  # '''Note''': This class replaces the previous OrderedSource class
  # 
  # The collection is contained in the ordered_objects - if you ever use that
  # accessor all "ordering" relations for the object will be completely overwritten
  # on saving. (You can still assign the predicates manually as long as the
  # ordered_objects accesssor is not called before saving.)
  class Collection < Source
    
    include Enumerable

    before_save :rewrite_order_relations
    after_save :force_rdf_rewrite

    # Initialize SeqContainer
    def self.new(uri)
      collection = super(uri)
      collection.autosave_rdf = false # Will do this by ourselves
      collection
    end
    
    # Many methods are directly forwarded to the underlying array
    [:+, :<<, :==, :[]=, :at, :clear, :collect, :delete_at, :delete, :each, 
    :each_index, :empty?, :include?, :index, :join, :last, :length, :size].each do |method|
      eval <<-EOM
        def #{method}(*args, &block)
          ordered_objects.send(:#{method}, *args, &block)
        end
      EOM
    end
    
    # This can be used both for predicates and collection items - if an integer
    # value is passed, the method will assume that it is an access on the 
    # collection item with that number
    def [](index_or_predicate)
      if(index_or_predicate.is_a?(Fixnum))
        ordered_objects[index_or_predicate]
      else
        super
      end
    end
    
    # See #[] method
    def []=(index_or_predicate, value)
      if(index_or_predicate.is_a?(Fixnum))
        ordered_objects[index_or_predicate] = value
      else
        super
      end
    end
    
    # Returns all elements (not the relations) in an ordered array. 
    # The contained sources will appear in the sequential order in which they
    # are contained in the collection, but there is no direct relation between
    # the index in the collection and the index returned through this method.
    #
    # The ordering of the elements will be preserved, though.
    def elements
      # execute query
      ordered_objects.compact
    end
      
    # return string for index
    def index_to_predicate(index)
      self.class.index_to_predicate(index)
    end
      
    # return index of predicate
    def predicate_to_index(predicate)
      self.class.predicate_to_index(predicate)
    end
    
    # return string for index
    def self.index_to_predicate(index)
      'http://www.w3.org/1999/02/22-rdf-syntax-ns#_' << ("%06d" % index.to_i) 
    end
    
    # return index of predicate
    def self.predicate_to_index(predicate)
      predicate.sub('http://www.w3.org/1999/02/22-rdf-syntax-ns#_', '').to_i
    end
    
    private

    # Returns all the objects that are ordered in an array where the array
    # index equals the position of the object in the ordered set. The array
    # is zero-based, position that don't have an object attached will be set to 
    # nil.
    def ordered_objects
      return @ordered_objects if(@ordered_objects)
      relations = query
      # Let's assume the follwing is a sane assumption ;-)
      # Even if a one-base collection comes in, we need to push just one element
      @ordered_objects = Array.new(relations.size)
      # Now add the elements so that the relation property is reflected
      # on the position in the array
      relations.each do |rel|
        index = rel.rel_order
        @ordered_objects[index] = rel.object
      end

      @ordered_objects
    end

    # This will be called before saving and will completely rewrite the relations
    # that make up the ordered store, based on the internal array
    def rewrite_order_relations
      return unless(@ordered_objects) # If this is nil, the relations weren't loaded in the first place
      objects = ordered_objects # Fetch them before deleting
      # Now destroy the existing elements
      SemanticRelation.destroy_all(['subject_id = ? AND rel_order IS NOT NULL', self.id])
      SemanticRelation.destroy_all(['subject_id = ? AND predicate_uri = ?', self.id, N::DCT.hasPart.to_s])
      # rewrite from the relations array
      objects.each_index do |index|
        if(obj = objects.at(index)) # Check if there's a value to handle
          # Create a new relation with an order
          self[index_to_predicate(index)].add_with_order(obj, index)
          self[N::DCT.hasPart] << obj
        end
      end
    end
    
    
    def force_rdf_rewrite
      create_rdf(:force)
    end

    # execute query and return the result
    def query(scope = :all)
      # execute query
      self.semantic_relations.find(scope, :conditions => 'rel_order IS NOT NULL', :order => :rel_order)
    end

  end
end
