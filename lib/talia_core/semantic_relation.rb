# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

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
    before_save :check_for_object

    # BY RIK 20101221
    # Utility method.
    # Returns a list of all predicates currently used in any relation.
    def self.all_predicates
      @all_predicates ||= begin
        sql  = "SELECT DISTINCT predicate_uri FROM semantic_relations"
        @all_predicates = self.find_by_sql(sql).collect do |predicate|
          predicate.predicate_uri
        end.compact
      end
    end

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
    
    # An item will be equal to its #value - this is a little hack that lets Enumerable#find and
    # such methods work easily on collections of SemanticRelation.
    #
    # If compare is a SemanticRelation, this will be true if both relations have the same predicate
    # value.
    def ==(compare)
      if(compare.is_a?(SemanticRelation))
        (self.predicate_uri == compare.predicate_uri) && (self.value == compare.value)
      else
        self.value == compare
      end
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
    
    # Called on save, this will check if the "same" object already exists in the database.
    # If yes, it will use the version from the database instead of the one currently attached,
    # since a "new" source with an existing URI cannot be saved.
    def check_for_object
      if(self.object.new_record? && self.object.is_a?(ActiveSource))
        existing = ActiveSource.find(:first, :conditions => { :uri => self.object.uri.to_s })
        self.object = (existing || self.object)
      end
    end

  end
end
