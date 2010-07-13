module TaliaCore
  
  # The basic class to represent a semantic relation, which is equivalent
  # to an RDF triple.
  #
  # The predicate is directly contained in the record is a string, while
  # the subject refers to respective ActiveSource object.
  #
  # The object of the relation refers either to another ActiveSource or
  # to a SemanticProperty, depending on the object_type field. This is
  # a normal polymorphic relation to the active_sources/semantic_properties
  # table(s)
  class SemanticRelation < ActiveRecord::Base
    
    belongs_to :subject, :class_name => 'TaliaCore::ActiveSource'
    belongs_to :object, :polymorphic => true
    before_destroy :discard_property
    before_destroy :destroy_dependent_object

    # Returns true if the Relation matches the given predicate URI (and value,
    # if given). A relation matches if the predicate of this relation is
    # them same as the predicate given (which can be a String or a Source or
    # a N::URI) and if the object's value (or uri, if the object is a 
    # ActiveSource) is the same as the value given.
    def matches?(predicate, value = nil)
      if(value)
        if(value.is_a?(ActiveSource) || value.is_a?(SemanticProperty))
          (predicate_uri == predicate.to_s) && (value == object)
        else
          return false unless(object.is_a?(SemanticProperty))
          (predicate_uri == predicate.to_s) && (object.value == value)
        end
      else
        predicate_uri == predicate.to_s
      end
    end

    # Return the "value" of the relation. This is usually the same as #object,
    # except that string values are parsed as PropertyString objects and that
    # in case the "special type" is set the related resources are made to
    # be objects of that type (see above).
    def value
      semprop = object.is_a?(SemanticProperty)
      if(special_object_type)
        assit(object, "Must have object for #{predicate_uri}")
        raise(ArgumentError, 'Must not have a property for a typed item') if(semprop)
        special_object_type.new(object.uri.to_s)
      elsif(semprop)
        # Plain, return the object or the value for SemanticProperties
        object.value ? PropertyString.parse(object.value) : object.value
      else
        object
      end
    end
    
    # An item will be equal to it's #value
    def ==(compare)
      self.value == compare
    end
    
    # This will return the "object type" for the current relation. This can
    # be used to "force" a relation for some predicates.
    #
    # This will check if an entry exists for the current predicate has an
    # entry in #special_types. If yes, the class will be returned.
    #
    # If object_type returns a class, the #value method will return objects
    # of that class for all resources. 
    #
    # The default case is that this returns nil, which will cause #value
    # to return the actual "object" value for relations to resources.
    def special_object_type
      self.class.special_types[predicate_uri]
    end
    
    # Simple hash that checks if a type if property requires "special" handling
    # This will cause the wrapper to accept ActiveSource relations and all
    # sources will be casted to the given type
    def self.special_types
      @special_types ||= {
        N::RDF.type.to_s => N::SourceClass
      }
    end

    private
    
    # If the object of this relation is a SemanticProperty, it will
    # be deleted from the database by this method.
    def discard_property
      if(object.is_a?(SemanticProperty))
        SemanticProperty.delete(object.id)
      end
    end
    
    def destroy_dependent_object
      object.destroy if(object.is_a?(ActiveSource) && subject.property_options_for(predicate_uri)[:dependent] == :destroy)
    end

  end
end
