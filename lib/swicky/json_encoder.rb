module Swicky

  # Takes a number of triples and encodes them in the SIMILE JSON format
  class JsonEncoder

    def initialize(triples)
      @triples = triples
      @types_hash = {}
      @properties_hash = {}
      @label_hash = {}
      @label_inverse = {}
    end

    def to_json
      puts @triples.inspect
      @items ||= begin
        items = []
        # First a round to make sure that each item has a label
        triple_hash.each { |object, values| values['label'] = make_label!(object, values) }
        # Now build the items themselves
        triple_hash.each { |object, values| items += build_item(object, values) }
        items
      end
      # hashy = { 'items' => @items, 'types' => @types_hash, 'properties' => @properties_hash }
      # puts hashy.inspect
      { 'items' => @items, 'types' => @types_hash, 'properties' => @properties_hash }.to_json
    end  

    private

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

    # Builds the entry for one "item". This alwasys returns an array, as there may
    # be additional items created as placeholders for label references
    def build_item(object, values)
      items = []
      item = {}
      item['uri'] = object.to_s

      item['type'] = make_types!(values)
      item['label'] = values.delete('label')

      # Add the normal predicates
      values.each do |predicate, objects|
        predicate_local = make_predicate_local(predicate)
        resource_labels, additional_items = as_labels(objects)
        item[predicate_local] = resource_labels
        items += additional_items
      end
      
      items << item
      items
    end
    
    # Turns the given resources into label references
    def as_labels(resources)
      additional_items = []
      labels = resources.collect do |res| 
        label, additional = resource_label(res) 
        additional_items << additional if(additional)
        label
      end
      labels.uniq!
      [(labels.size == 1) ? labels.first : labels, additional_items]
    end
    
    def resource_label(resource)
      return resource if(resource.is_a?(String))
      return @label_inverse[resource.to_s] if(@label_inverse[resource.to_s])
      label = make_label!(resource, {})
      [label, {'uri' => resource.to_s, 'label' => label}]
    end

    # Check the type definitions from the given hash and transform them
    # to "type" entries in the JSON structure
    def make_types!(hash)
      # First, check for the types
      types = hash.delete(get_key_from(N::RDF.type, hash)) || []
      # Add a default type if we don't have one
      if(types.empty?)
        types = [ N::RDF.Resource ]
      end
      # All types will be referred to by their local name
      types.collect! { |type| make_type_local(type) }
      types.uniq!
      types
    end
    
    
    # Create the label: Either use the RDFS label or the last part of th
    # uri. This also inserts the label into an "inverse" hash so that 
    # labels can be looked up by the uri
    def make_label!(uri, hash)
      return @label_inverse[uri.to_s] if(@label_inverse[uri.to_s]) # label already exists
      label = hash.delete(get_key_from(N::RDFS.label, hash)) || []
      if(label.empty?)
        label = check_label(label_for(uri), uri)
      else
        label = check_label(label.first, uri)
      end
      
      label.to_s
    end

    # Get the part of the the uri that can be used as a label
    def label_for(uri)
      /[\/#]?([^\/#]+)\Z/.match(uri.to_s)[1]
    end
    
    # Check if the given label can be used, and adapt it if necessary
    def check_label(label, uri)
      label = first_free(label, uri.to_s, @label_hash)
      @label_inverse[uri.to_s] ||= label
      label
    end

    # Little kludge for getting badly-specified keys
    def get_key_from(key, hash)
      hash.keys.find { |k| k.to_s == key.to_s }
    end
    
    # Finds the first "free" element in the hash. This checks
    # if hash[initial_value] is empty or equal to "value", if that is not the
    # case if will try "initial_value2", "initial_value3", ... until the
    # condition is fulfilled
    def first_free(initial_key, value, hash)
      candidate = initial_key
      hash[candidate] ||= value
      count = 1
      while(hash[candidate] != value)
        count += 1
        candidate = "#{initial_key}#{count}"
        hash[candidate] ||= value
      end
      candidate
    end

    # Create the local name for the predicate, and add the definition
    # to the "properties" hash if necessary. This will also attempt to
    # avoid collisions if some predicates map to the same local name
    #
    # TODO: Doesn't force RDF:label etc to map to the "correct" local 
    #       name in case of collisions
    def make_predicate_local(predicate)
      first_free(predicate.to_uri.local_name, { 'uri' => predicate.to_s, 'valueType' => 'item' }, @properties_hash)
    end

    # Making local for types
    def make_type_local(type)
      first_free(type.to_uri.local_name, { 'uri' => type.to_s }, @types_hash)
    end


    # The entry for the "properties" hash for the given predicate
    def predicate_property(predicate_uri)
      {
        "uri" => predicate_url,
        "valueType" => "item"
      }
    end

  end

end