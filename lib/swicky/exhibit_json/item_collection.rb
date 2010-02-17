module Swicky
  module ExhibitJson

    # Takes a number of triples and encodes them in the SIMILE JSON format.
    # See http://simile.mit.edu/wiki/Exhibit/Understanding_Exhibit_Database
    class ItemCollection

      def initialize(triples)
        @triples = triples
        triple_hash.each { |object, values| add_item(object, values) }
      end

      def to_json(*a)
        my_types = {}
        types.values.each { |t| my_types[t.id] = t }
        my_properties = {}
        properties.values.each { |p| my_properties[p.id] = p }
        {
          'items' => items.values,
          'types' => my_types,
          'properties' => my_properties
        }.to_json(*a)
      end

      def triple_hash
        @triple_hash ||= begin
          triple_hash = {}
          # Sort all the triples into a hash, mapping all predicates
          # to a single subject entry and all objects into a single
          # predicate entry for each subject or predicate
          @triples.each do |triple|
            subject = triple.shift.to_uri
            triple_hash[subject] ||= {}
            predicate = triple.shift.to_uri
            triple_hash[subject][predicate] ||= []
            triple_hash[subject][predicate] << triple.first
          end
          triple_hash
        end
      end

      def add_item(item, values = nil)
        items[item.to_s] = Item.new(item, self) if(!items[item.to_s])
        items[item.to_s].add_properties(values) if(values)
        items[item.to_s].id
      end

      def add_type(type)
        types[type.to_s] = Item.new(type, self) if(!types[type.to_s])
        types[type.to_s].id
      end
      
      def add_property(prop, value_type)
        properties[prop.to_s] = Item.new(prop, self) if(!properties[prop.to_s])
        if(!properties[prop.to_s]['valueType'])
          properties[prop.to_s]['valueType'] = value_type
        end
        properties[prop.to_s].id
      end

      # Make a unique id for the given item, based on the label of the item
      def make_id(item)
        if(id_hash_inv[item.uri]) # Already existing id
          id_hash_inv[item.uri]
        else
          first_free(item.label, item.uri)
        end
      end

      private 

      # Finds the first "free" element in the hash. This checks
      # if hash[initial_value] is empty or equal to "value", if that is not the
      # case if will try "initial_value2", "initial_value3", ... until the
      # condition is fulfilled
      def first_free(initial_key, uri)
        candidate = initial_key
        id_hash[candidate] ||= uri
        count = 1
        while(id_hash[candidate] != uri)
          count += 1
          candidate = "#{initial_key}#{count}"
          id_hash[candidate] ||= uri
        end
        id_hash_inv[uri] ||= candidate
        candidate
      end
      
      def types
        @types ||= {}
      end
      
      def properties
        @properties ||= {}
      end

      def id_hash
        @id_hash ||= {}
      end
      
      def items
        @items ||= {}
      end

      def id_hash_inv
        @id_hash_inv ||= {}
      end

    end
  end
end