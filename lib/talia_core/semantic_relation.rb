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

    class << self

      # Retrieves the "fat relations" for the given source and predicate. This
      # will join all the tables for the objects and will select all the
      # data that is needed to not only construct the semantic relation
      # itself, but also the "object" record for the relation.
      def find_fat_relations(source, predicate)
        joins = ActiveSource.sources_join
        joins << ActiveSource.props_join
        relations = SemanticRelation.find(:all, :conditions => {
            :subject_id => source.id,
            :predicate_uri => predicate
          },
          :joins => joins,
          :select => fat_record_select
        )
        relations
      end

      # The "select" clause for selecting "fat" records for find_fat_relations and other
      # similar purposes
      def fat_record_select
        @select ||= begin
          select = 'semantic_relations.id AS id, semantic_relations.created_at AS created_at, '
          select << 'semantic_relations.updated_at AS updated_at, '
          select << 'semantic_relations.rel_order AS rel_order,'
          select << 'object_id, object_type, subject_id, predicate_uri, '
          select << 'obj_props.created_at AS property_created_at, '
          select << 'obj_props.updated_at AS property_updated_at, '
          select << 'obj_props.value AS property_value, '
          select << 'obj_sources.created_at AS object_created_at, '
          select << 'obj_sources.updated_at AS object_updated_at, obj_sources.type AS  object_realtype, '
          select << 'obj_sources.uri AS object_uri'
          select
        end
      end

    end

    private
    
    # If the object of this relation is a SemanticProperty, it will
    # be deleted from the database by this method.
    def discard_property
      if(object.is_a?(SemanticProperty))
        SemanticProperty.delete(object.id)
      end
    end

  end
end
