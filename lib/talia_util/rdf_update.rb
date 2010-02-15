module TaliaUtil
  
  # Some methods to update the RDF store. There is no real inferencing, just
  # some hardcoded rules that help to provide basic functionality with simple
  # RDF stores.
  class RdfUpdate
    
    class << self
      
      # This is the wrapper for rdfs_from_owl for the rake task
      def owl_to_rdfs
        puts "Checking for OWL classes."
        # Register the namespaces for ActiveRDF
        ActiveRDF::Namespace.register(:rdfs, N::RDFS.to_s)
        ActiveRDF::Namespace.register(:owl, N::OWL.to_s)
        progress = nil
        size, modified, blanks = rdfs_from_owl do |size|
          progress ||= begin
            puts "#{size} OWL classes found, adding rdfs:Class type for each."
            ProgressBar.new("Updating RDF database", size)
          end
          progress.inc
        end
        
        progress.finish if(progress)
        puts "Finished updating. Updated #{modified} of #{size} classes. #{blanks} blank nodes were ignored."
        
      end
      
      # This checks for owl:Classes and adds and rdfs:Class triple to them. This
      # doesn't check if the triple already exists, and thus may cause duplicates.
      # You can pass a block that will be called with the overall size
      # as a parameter.
      #
      # It returns the overall size, the number of modified elements and the
      # number of blank nodes
      def rdfs_from_owl
        # Remove previous auto rdfs triples
        ActiveRDF::FederationManager.clear(N::TALIA.auto_rdfs.context)
        
        # This gets all OWL classes in the store
        all_qry = ActiveRDF::Query.new(N::URI).distinct.select(:class)
        all_qry.where(:class, N::RDF::type, N::OWL.Class)
        all_owl = all_qry.execute
        
        # This gets all OWL classes that already have an RDF class attached
        qry_rdfs = ActiveRDF::Query.new(N::URI).distinct.select(:class)
        qry_rdfs.where(:class, N::RDF::type, N::OWL.Class)
        qry_rdfs.where(:class, N::RDF::type, N::RDFS.Class)
        classes_with_rdfs = qry_rdfs.execute
        
        
        modified = 0
        blanks = 0
        
        class_hash = {}
        
        # Put all the existing owl classes in a hash
        all_owl.each do |owl_class|
          if(owl_class.is_a?(RDFS::BNode))
            blanks = blanks + 1
            next
          end
          
          class_hash[owl_class] = :has_rdfs_class
        end
        
        # Now remove the ones that already have an RDF class
        classes_with_rdfs.each do |owl_class|
          next if(owl_class.is_a?(RDFS::BNode))
          
          class_hash[owl_class] = :no_rdfs_class
        end
        
        # Now go through all klasses and add the missing triples
        class_hash.each do |klass, status|
          if(status == :has_rdfs_class)
            modified = modified + 1
            ActiveRDF::FederationManager.add(N::URI.new(klass), N::RDF.type, N::RDFS.Class, N::TALIA.auto_rdfs_context)
          end
          yield(class_hash.size) if(block_given?)
        end
        
        return [class_hash.size, modified, blanks]
      end
      
    end
  end
end
