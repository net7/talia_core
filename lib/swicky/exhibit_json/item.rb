require 'digest/md5'

module Swicky
  module ExhibitJson

    # An item in the Exhibit JSON. Each item belongs to a collection.
    class Item

      attr_reader :element, :collection


      def initialize(element, collection)
        raise(ArgumentError, "Element must have an URI, was a #{element.class.name}: #{element.inspect}") unless(element.respond_to?(:uri))
        raise(ArgumentError, "Element must always belong to a collection") unless(collection)
        @original_properties = {}
        @element = element
        @properties = {}
        @collection = collection
        create_label!
        @properties['uri'] = self.uri
        @properties['id'] = @collection.make_id(self)
        @properties['hash'] = ('h_' << Digest::MD5.hexdigest(self.uri))
      end

      def uri
        @element.uri.to_s
      end
      
      def id
        @properties['id']
      end
      
      def label
        @properties['label']
      end
      
      def [](key)
        @properties[key]
      end
      
      def []=(key, value)
        @properties[key] = value
      end
      
      def add_properties(properties)
        @original_properties = properties
        create_label!
        create_types!
        create_properties!
      end
      
      def to_json(*a)
        @properties.to_json(*a)
      end
      
      private

      def create_label!
        label = delete_with_key(N::RDFS.label) # Get the "real" label from the RDFS
        if(@properties['label'].blank?) 
          # In this case we have no existing label on the item,
          # so if we don't have the RDFS label we create one from the URI
          label = label.blank? ? label_for(self.uri) : label.first
          @properties['label'] = label
        else
          # We already have a label on the item, which we only 
          # overwrite in case there is a "real" label
          @properties['label'] = label.first unless(label.blank?)
        end
        assit_kind_of(String, @properties['label'])
      end
      
      def create_types!
        types = delete_with_key(N::RDF.type)
        types = [ N::RDF.Resource ] if(types.blank?)
        types.collect! { |t| collection.add_type(t) }
        types.uniq!
        @properties['type'] = types
      end
      
      def create_properties!
        @original_properties.each do |key, values|
          value_type = values.first.respond_to?(:uri) ? 'item' : 'text'
          prop = collection.add_property(key, value_type)
          prop_values = values.collect do |object| 
            object.respond_to?(:uri) ? collection.add_item(object) : object
          end
          prop_values.uniq!
          if(@properties[prop].blank?)
            @properties[prop] = (prop_values.size == 1) ? prop_values.first : prop_values
          else
            if(@properties[prop].is_a?(Array))
              @properties[prop] += prop_values
            else
              @properties[prop] = (prop_values << @properties[prop])
            end
          end
        end
      end

      # Little kludge for getting badly-specified keys
      def delete_with_key(key)
        real_key = @original_properties.keys.find { |k| k.to_s == key.to_s }
        @original_properties.delete(real_key)
      end

      # Get the part of the the uri that can be used as a label
      def label_for(uri)
        if(uri =~ /xpointer/)
          'An Xpointer'
        else
          uri_fragment(uri)
        end
      end

      def uri_fragment(uri)
        raise(ArgumentError, "Must have a real uri") unless(uri)
        fragment_match = /[\/#]?([^\/#]+)\Z/.match(uri.to_s)
        fragment_match ||= /([^\.\/]+)\.[^\.]*\Z/.match(uri.to_s)
        if(fragment_match && fragment_match[1] && (fragment_match[1].size > 2))
          URI.escape(fragment_match[1])
        else
          Digest::MD5.hexdigest(uri.to_s)
        end
      end

    end
  end
end
