require 'oai'
require_or_load File.join(File.dirname(__FILE__), 'active_source_oai_adapter', 'class_methods')

module TaliaCore
  module Oai
    
    # Wraps an ActiveSource record so that it provides the accessor methods
    # for DublinCore. In a nutshell, this makes the object look like an
    # ActiveRecord with "fields" like "title" or "subject". The OAI provider
    # can access those fields to automatically read the metatdata from the
    # records.
    #
    # == Wrapping an ActiveSource
    # 
    # Use ActiveSourceOaiAdapter.get_wrapper_for(record) to create a new
    # wrapper object for a given ActiveSource. Usually the ActiveSourceModel
    # will do this automatically.
    #
    # == Extending the adapter
    #
    # If you need more specific functionality, you may subclass the adapter
    # or write your own adapter class that includes OaiAdapterClassMethods
    #
    # In both cases you'll get the #namespace_field class method - this will
    # allow you to define accessors to properties in the following way:
    #
    #  # This maps the dcns:title and dcns:foo properties on the original 
    #  # source to the #title and #foo accessors
    #  namespace_field :dcns, :title, :foo
    #
    class ActiveSourceOaiAdapter
      
      extend OaiAdapterClassMethods
      
      namespaced_field :dcns, :title, :subject, :description, :publisher,
        :contributor, :date, :format,
        :source, :language, :relation, :coverage, :rights
      
      namespaced_field :dct, :isPartOf, :abstract

      # namespaced field for Europeana
      namespaced_field :userTag, :unstored, :object, :provider,
                       :uri, :year, :hasObject, :country
      
      # Type information. Base class is not terribly useful, but needed to
      # overwrite default #type method
      def type
        ''
      end
      
      def initialize(record)
        assit_kind_of(ActiveSource, record)
        @record = record
      end
      
      # Get the author/creator
      def creator
        @record[N::DCNS.creator].collect do |creator|
          if(creator.is_a?(TaliaCore::ActiveSource))
            author = ''
            author_name = creator.hyper::author_name.first
            author << author_name << ' ' if(author_name)
            author_surname = creator.hyper::author_surname.first || ''
            author << author_surname if(author_surname)
            author = "No lookup. Author should be at #{creator.uri}" if(author == '')
            author
          else
            creator
          end
        end
      end
      
      # Identifier for the resource
      def identifier
        @record.uri.to_s
      end
      
      # Timestamp for the record
      def created_at
        @record.created_at
      end
      
      # Id for the record
      def id
        @record.id
      end
      
      # Tries to instanciate a wrapper object for the record, using the 
      # wrapper class that corresponds to the given record's class
      def self.get_wrapper_for(records)
        if(records.is_a?(ActiveSource))
          self.new(record)
        elsif(records.respond_to?(:collect))
          records.collect { |rec| self.new(rec) }
        elsif(records.nil?)
          nil
        else
          raise(ArgumentError, "Don't know how to wrap #{records.inspect}")
        end
      end      

      
    end
    
  end
end
