module TaliaCore

  # This is a single item in a semantic collection wrapper. It contains either a
  #
  # * fat_relation - a SemanticRelation with all the columns needed to build the
  #   related objects
  # * plain_relation - a normal semantic relation object 
  #
  # Only one of the above should be usually given. If a fat relation is given, 
  # the user of this class can access the #value/#object of the relation without
  # having to perform a database query. 
  class SemanticCollectionItem

    attr_reader :plain_relation, :fat_relation

    # Create a new collection it. The plain_or_fat flag can either be :_plain_
    # or :_fat_, indicating wether the SemanticRelation passed in is a normal
    # or a "fat" relation.
    #
    # A "special type" may be configured for particular relations (see 
    # SemanticCollectionWrapper). If one is defined, all related resource will
    # be returned as objects of this type. In practice this is only used for
    # rdf:type (to force the related objects to N::SourceClass).
    def initialize(relation, plain_or_fat)
      case plain_or_fat
      when :plain
        @plain_relation = relation
      when :fat
        @fat_relation = relation
      else
        raise(ArgumentError, "Unknown type")
      end
      @object_type = SemanticCollectionWrapper.special_types[relation.predicate_uri.to_s]
    end

    # The relation for this collection item
    def relation
      @fat_relation || @plain_relation
    end

    # Return the "value" of the relation. This is usually the same as #object,
    # except that string values are parsed as PropertyString objects and that
    # in case the "special type" is set the related resources are made to
    # be objects of that type (see above).
    def value
      semprop = object.is_a?(SemanticProperty)
      if(@object_type)
        assit(object, "Must have object for #{relation.predicate_uri}")
        raise(ArgumentError, 'Must not have a property for a typed item') if(semprop)
        @object_type.new(object.uri.to_s)
      elsif(semprop)
        # Plain, return the object or the value for SemanticProperties
        object.value ? PropertyString.parse(object.value) : object.value
      else
        object
      end
    end

    # Creates an object from the relation. If a fat relation was given, this
    # will not hit the database.
    def object
      @object ||= begin
        if(@fat_relation)
          create_object_from(@fat_relation)
        elsif(@plain_relation)
          @plain_relation.object
        else
          raise(ArgumentError, "No relation was given to this object")
        end
      end
    end

    # An item will be equal to it's #value
    def ==(compare)
      self.value == compare
    end

    # Creates an object from the given "fat" relation. This retrieves the data
    # from the relation object and instantiates it just like it would be after
    # a find operation.
    def create_object_from(fat_relation)
      # First we find out which class (table our target object is in)
      klass = fat_relation.object_type.constantize
      record = nil
      if(klass == TaliaCore::ActiveSource)
        # We prepare a hash of properties for the ActiveSource
        record = {
          'uri' => fat_relation.object_uri,
          'created_at' => fat_relation.object_created_at,
          'updated_at' => fat_relation.object_updated_at,
          'type' => fat_relation.object_realtype
        }
      elsif(klass == TaliaCore::SemanticProperty)
        # We prepare a hash of properties for the SemanticProperty
        record = {
          'value' => fat_relation.property_value,
          'created_at' => fat_relation.property_created_at,
          'updated_at' => fat_relation.property_updated_at
        }
      end
      # Common attributes
      record['id'] = fat_relation.object_id
      # Instantiate the new record
      klass.send(:instantiate, record)
    end

  end

end
