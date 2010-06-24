module TaliaCore
  module ActiveSourceParts
    
    # Methods for ActiveSource objects for accessing and handling predicates, which are the
    # properties connected to the source. When accessing a predicate/property of an ActiveSource,
    # the system will return a SemanticCollectionWrapper.
    #
    # Once a predicate is loaded, the ActiveSource will cache the SemanticCollectionWrapper
    # internally, and will re-use it on subsequent accesses. 
    #
    # If the relations are prefetched (usually by providing the :prefetch_relations option to
    # the find Method, see the Finders module), all wrappers for the source are loaded at once;
    # the actual prefetching is done by the prefetch_relations_for method, which can also be
    # used directly on a collection of sources.
    module PredicateHandler

      # Predicate-related class methods. See the PredicateHandler module for more
      module ClassMethods

        # Attempts to fetch all relations on the given sources at once, so that
        # there is potentially only one.
        #
        # For safety reasons, there is a limit on the number of sources that is
        # accepted. (For a web application, if you go over the default, you're
        # probably doing it wrong).
        #
        # When prefetching, all the relations/properties for the given sources are
        # loaded in a single request, and the data is injected in the internal cache
        # of the sources. 
        #
        # A source with prefetched relations will not cause database queries if you
        # access its properties.
        def prefetch_relations_for(sources, limit = 1024)
          sources = [ sources ] if(sources.is_a?(ActiveSource))
          raise(RangeError, "Too many sources for prefetching.") if(sources.size > limit)
          src_hash = {}
          sources.each { |src| src_hash[src.id] = src }
          conditions = { :subject_id => src_hash.keys }
          joins = ActiveSource.sources_join
          joins << ActiveSource.props_join
          relations = SemanticRelation.find(:all, :conditions => conditions,
          :joins => joins,
          :select => SemanticRelation.fat_record_select
          )
          relations.each do |rel|
            src_hash[rel.subject_id].inject_predicate(rel)
          end

          # Set all as loaded
          sources.each do |src|
            src.each_cached_wrapper { |wrap| wrap.instance_variable_set(:'@loaded', true) }
            src.instance_variable_set(:'@prefetched', true)
          end
        end

      end # End class methods

      # Gets the RDF types for the source. This is equivalent to accessing the
      # rdf:type predicate.
      def types
        get_objects_on(N::RDF.type.to_s)
      end
      
      # Checks if the source has the given RDF type
      def has_type?(type)
        (self.types.include?(type))
      end

      # Returns the SemanticCollectionWrapper for the given predicate. The collection
      # wrapper will be cached internally, so that subsequent calls will receive the
      # same collection wrapper again.
      #
      # This also means that any modifications to the wrapper are preserved in the 
      # cache - if a wrapper is modified in memory, and accessed again _on the same
      # source_, a subsequent access will return the modified wrapper.
      #
      # Modified wrappers are saved when the ActiveSource itself is saved (through
      # save_wrappers, which is automatically called)
      def get_objects_on(predicate)
        @type_cache ||= {}
        active_wrapper = @type_cache[predicate.to_s]

        if(active_wrapper.nil?)
          active_wrapper = SemanticCollectionWrapper.new(self, predicate)
          
          # If this is a prefetched source we have everything, so we can 
          # initialize the wrapper without loading anything
          active_wrapper.init_as_empty! if(@prefetched)
          
          @type_cache[predicate.to_s] = active_wrapper
        end
        
        active_wrapper
      end

      # Goes through the existing SemanticCollectionWrappers in the cache, and
      # saves any modifications that may exist.
      #
      # This is automatically called when the source is saved.
      def save_wrappers
        each_cached_wrapper do |wrap|
          # Load unloaded if we're not rdf_autosaving. Quick hack since otherwise
          # since the blanking of unloaded properties could cause problems with
          # the rdf writing otherwise
          wrap.send(:load!) unless(wrap.loaded? || autosave_rdf?)
          wrap.save_items!
        end
      end

      # Loops through the wrapper cache and passes each of the SemanticCollectionWrappers
      # in the cache to the block given to this method
      def each_cached_wrapper
        return unless(@type_cache)
        @type_cache.each_value {  |wrap| yield(wrap) }
      end

      # Resets the internal cache of wrappers/properties. Any unsaved changes on
      # the wrappers are lost, and get_object_on will have to reload all data when it is
      # called again
      def reset!
        @type_cache = nil
      end

      # Injects a 'fat relation' into the cache/wrappter. A "fat" relation is a 
      # SemanticRelation which contains additional fields (e.g. the subject uri, all
      # object information, etc.) - See also the SemanticCollectionWrapper documentation.
      def inject_predicate(fat_relation)
        wrapper = get_objects_on(fat_relation.predicate_uri)
        wrapper.inject_fat_item(fat_relation)
      end
    end
  end
end