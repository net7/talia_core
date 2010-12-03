# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module ActiveSourceParts

    # Methods for the ActiveSource class to automatically create the RDF triples
    # for a source and to access the RDF data of the source.
    #
    # The RDF for a source will be automatically created through the auto_create_rdf
    # callback when the source is set (and autosave_rdf is set)
    module RdfHandler

      # Returns the value of the autosave_rdf flag, as set by autosave_rdf=
      def autosave_rdf?
        @autosave_rdf = true unless(defined?(@autosave_rdf))
        @autosave_rdf
      end

      # This can be used to turn of automatic rdf creation. If set to true, 
      # create_rdf will *not* be called automatically after saving the source.
      # 
      # *Attention*: Improper use will compromise the integrity of the RDF data. 
      # However, it may
      # be used in order to speed up operations that save a record
      # several times and don't need the RDF data in the meantime.
      def autosave_rdf=(value)
        @autosave_rdf = value
      end

      # Returns the RDF object to use for this ActiveSource. This
      # will return a RdfResource, which has a similiar (but more
      # limited API) than the ActiveSource itself. All operations and
      # queries on that resource will go to the RDF store instead of the
      # database
      def my_rdf
        @rdf_resource ||= begin
          src = RdfResource.new(uri)
          src.object_class = TaliaCore::ActiveSource
          src
        end
      end

      # This creates the RDF subgraph for this Source and saves it to disk. This
      # may be an expensive operation since it removes the existing elements.
      # (Could be optimised ;-)
      #
      # Unless the force option is specified, this will ignore predicates that
      # remain unchanged. This means that writing will be faster if a predicate
      # will not changed, but if database objects were not added through the
      # standard API they'll be missed
      #
      # The force option may have three values: 
      #
      # [*false*] Normal operation. This retrieves the data for each of the 
      #           cached SemanticCollectionWrappers that may have been modified and rewrites
      #           the respective attribute in the RDF store. (see the PredicateHandler 
      #           module for an explanation of the wrapper cache). It will ignore wrappers that 
      #           are obviously "clean", but will do a "retrieve and write" for each wrapper 
      #           separately.
      # [*force*] Force a complete rewrite of the RDF data for this source. This will erase the
      #           RDF and write all triples for this source in one go. It will also remove
      #           any triples for this source that may have been added externally.
      # [*create*] Do not check for any existing data, just write out the data that is in the
      #            cache. This is fast, but must *only* be used for new sources where it is
      #            certain that no data for the source exists in the RDF store.
      def create_rdf(force = :false)
        self.class.benchmark("\033[32m\033[4m\033[1mActiveSource::RD\033[0m Creating RDF for source", Logger::DEBUG, false) do
          assit(!new_record?, "Record must exist here: #{self.uri}")
          # Get the stuff to write. This will also erase the old data
          
          s_rels = case force 
            when :force 
              prepare_all_predicates_to_write 
            when :create
              prepare_predicates_to_create
            else
              prepare_predicates_to_write
            end
          s_rels.each do |sem_ref|
            # We pass the object on. If it's a SemanticProperty, we need to add
            # the value. If not the RDF handler will detect the #uri method and
            # will add it as Resource.
            obj = sem_ref.object
            assit(obj, "Must have an object here. #{sem_ref.inspect}")
            value = obj.is_a?(SemanticProperty) ? obj.value : obj
            my_rdf.direct_write_predicate(N::URI.new(sem_ref.predicate_uri), value)
          end
          my_rdf.direct_write_predicate(N::RDF.type, rdf_selftype)
          my_rdf.save
        end
      end
      
      # Creates an RDF/XML resprentation of the source. See the Xml::RdfBuilder and the
      # Xml::SourceReader for more information.
      def to_rdf
        rdf = String.new

        ActiveSourceParts::Xml::RdfBuilder.open(:target => rdf, :indent => 2) do |builder|
          builder.write_source(self)
        end

        rdf
      end

      private

      # Get the "standard" predicates to write (which is just the ones changed
      # through the standard API. This will go through each of the cached
      # SemanticCollectionWrapper(s) and it will erase the triples for each
      # of the wrappers separately.
      def prepare_predicates_to_write
        preds_to_write = []
        each_cached_wrapper do |wrap|
          # If it wasn't loaded, it hasn't been written to
          next if(wrap.clean?)
          # Remove the existing data. TODO: Not using contexts
          my_rdf.remove(N::URI.new(wrap.instance_variable_get(:@assoc_predicate)))
          items = wrap.send(:items) # Get the items
          items.each { |it| preds_to_write << it }
        end
        preds_to_write
      end

      # This will get all existing predicates from the database. This will also
      # erase the rdf for this source completely in one go
      def prepare_all_predicates_to_write
        # TODO: Could load with a single sql
        my_rdf.clear_rdf # TODO: Not using contexts here
        SemanticRelation.find(:all, :conditions => { :subject_id => self.id }, :include => [ :object ])
      end
      
      # ATTENTION: This is a speed hack that avoids the usual checks based
      # on the assumption that this source was created from scratch, 
      # no attributes are in the store and all attributes are in-memory.
      def prepare_predicates_to_create
        preds_to_create = []
        each_cached_wrapper do |wrap|
          next if(wrap.clean?)
          # Evil, we get the items directly to avoid a useless load
          items = wrap.instance_variable_get(:@items)
          items.each { |it| preds_to_create << it }
        end
        preds_to_create
      end
      
      def auto_update_rdf
        create_rdf if(autosave_rdf?)
      end

      # On creation we force the full write, there's no use 
      # doing all checks if we know that nothing exists
      def auto_create_rdf
        create_rdf(:create) if(autosave_rdf?)
      end
      
      # Cleans out the RDF data before the source is destroyed
      def clear_rdf
        if autosave_rdf?
          ActiveRDF::FederationManager.delete(self, :predicate, :object)
          ActiveRDF::FederationManager.delete(:subject, :predicate, self)
        end
      end

    end
  end
end
