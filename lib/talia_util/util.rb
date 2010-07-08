# Utility module for tests, rake tasks etc.
module TaliaUtil

  # Main utility functions for Talia
  class Util
    class << self

      # Rake task helper. Get the list of files the <tt>files</tt>
      # environment variable (passed as <tt>file=[files]</tt>). Exits the
      # runtime and prints an error message if the variable is not set.
      #
      # This returns a FileList object with all the files that match the
      # pattern.
      def get_files
        puts "Files given: #{ENV['files']}"
        unless(ENV['files'])
          puts("This task needs files to work. Pass them like this files='something/*.x'")
          print_options
          exit(1)
        end

        FileList.new(ENV['files'])
      end

      # Gets the <tt>ontology_folder</tt> environment variable, as passed
      # to the rake task with <tt>ontology_folder=[folder]</tt>
      #
      # Defaults to <tt>RAILS_ROOT/ontologies</tt> if the variable is not
      # set.
      def ontology_folder
        ENV['ontology_folder'] || File.join(RAILS_ROOT, 'ontologies')
      end

      # Set up the ontologies from the ontology_folder. This clears
      # the RDF context for the ontologies, if possible. Then it will
      # load all ontologies in the ontology_folder into the store,
      # and run the RdfUpdate::owl_to_rdfs update.
      def setup_ontologies
        # Clear the ontologies from RDF, if possible
        adapter = ActiveRDF::ConnectionPool.write_adapter
        if(adapter.contexts?)
          TaliaCore::RdfImport.clear_file_contexts
        else
          puts "WARNING: Cannot remove old ontologies, adapter doesn't support contexts."
        end

        puts "Ontologies loaded from: #{ontology_folder}"
        files = Dir[File.join(ontology_folder, '*.{rdf*,owl}')]
        ENV['rdf_syntax'] ||= 'rdfxml'
        params = [ENV['rdf_syntax'], files]
        params << :auto if(adapter.contexts?)
        TaliaCore::RdfImport::import(*params)
        RdfUpdate::owl_to_rdfs
      end

      # Init the talia core system. Use to initialize the system for the 
      # rake tasks. This will just exit if the system is already initialized,
      # e.g. through Rails.
      #
      # See the rake:talia_core help task for options supported. Options
      # include <tt>talia_root</tt>, <tt>environment</tt>, <tt>config</tt>,
      # <tt>reset_db</tt> and <tt>reset_rdf</tt>
      def init_talia
        return if(TaliaCore::Initializer.initialized)

        # If we have Rails installed, just call the Rails config 
        # instead of running the manual init
        if(defined?(RAILS_ROOT) && File.exist?(File.join(RAILS_ROOT, 'config', 'environment.rb')))
          puts "\nInitializing Talia through Rails"
          load(File.join(RAILS_ROOT, 'config', 'environment.rb'))
        else

          # If options are not set, the initializer will fall back to the internal default
          TaliaCore::Initializer.talia_root = ENV['talia_root']
          TaliaCore::Initializer.environment = ENV['environment']

          config_file = ENV['config'] ? ENV['config'] : 'talia_core'

          # run the initializer
          TaliaCore::Initializer.run(config_file) do |config|
            unless(flag?('no_standalone'))
              puts "Always using standalone db from utilities."
              puts "Give the no_standalone option to override it."
              config['standalone_db'] = "true"
            end
          end
        end
        puts("\nTaliaCore initialized")

        # # Flush the database if requested
        if(flag?('reset_db'))
          flush_db
          puts "DB flushed"
        end

        # Flus the rdf if requested
        if(flag?('reset_rdf'))
          flush_rdf
          puts "RDF flushed"
        end
      end

      # Rake helper. Prints the talia configuration to the 
      # console.
      def talia_config
        puts "Talia configuration"
        puts ""
        puts "TALIA_ROOT: #{TALIA_ROOT}"
        puts "Environment: #{TaliaCore::CONFIG['environment']}"
        puts "Standalone DB: #{TaliaCore::CONFIG['standalone_db']}"
        puts "Data Directory: #{TaliaCore::CONFIG['data_directory_location']}"
        puts "Local Domain: #{N::LOCAL}"
      end

      # Rake/Startup helper. Prints out the talia version/header to the the console.
      def title
        puts "\nTalia Digital Library system. Version: #{TaliaCore::Version::STRING}" 
        puts "http://www.muruca.org/\n\n"
      end

      # Flush the SQL database. This deletes all entries *only* from the main Talia
      # tables in the db. Additional tables for user-defined models (e.g. translations)
      # will _not_ be touched.
      def flush_db
        [ 'active_sources', 'data_records', 'semantic_properties', 'semantic_relations', 'workflows'].reverse.each { |f| ActiveRecord::Base.connection.execute "DELETE FROM #{f}" }
        # Also remove the "unsaved cache" for the wrappers (may be important during testing)
        TaliaCore::SemanticCollectionWrapper.instance_variable_set(:'@unsaved_source_cache', {})
      end

      # Flush the RDF store. This clears the whole store, including triples that
      # were added through other means than the Talia API.
      def flush_rdf
        ActiveRDF::ConnectionPool.write_adapter.clear
      end

      # Remove the data directories. Removes the data directory (configured
      # as <tt>data_directory_location</tt> in talia_core.yml) and the iip directory
      # (configured as <tt>iip_root_location</tt> in talia_core.yml). 
      #
      # This ignores non-existing directories without an error message.
      def clear_data
        data_dir = TaliaCore::CONFIG['data_directory_location']
        iip_dir = TaliaCore::CONFIG['iip_root_directory_location']
        FileUtils.rm_rf(data_dir) if(File.exist?(data_dir))
        FileUtils.rm_rf(iip_dir) if(File.exist?(iip_dir))
      end


      # Do a full reset of the data store. Equivalent to clearing
      # the Talia SQL tables, the RDF store and the data directories.
      # This will re-initialize the ontologies afterwards.
      def full_reset
        flush_db
        flush_rdf
        clear_data
        setup_ontologies
      end

      # Rewrite the RDF for the whole database. Erases the RDF  store 
      # completely and re-builds the graph from the data in the SQL
      # tables. 
      #
      # *Warning:* This will *loose* all information contained in the
      # RDF that is not duplicated. This includes all SWICKY notebooks!
      #
      # Unless the turn_off_safety flag is set, or the environment variable
      # <tt>i_know_what_i_am_doing</tt> is set to "yes", this method will
      # print an error message and raise an exception.
      #
      # For each triple written, this will yield to the block (if one is given)
      # without parameters. For progress reporting, the overall number of
      # triples that will be rewritten can be acquired with #rewrite_count
      def rewrite_rdf(turn_off_safety=false)
        unless((ENV['i_know_what_i_am_doing'].yes?) || turn_off_safety)
          puts "WARNING: Rewriting the RDF will ERASE all data that does not come from the Talia API"
          puts "This includes ALL SWICKY notebooks"
          puts 
          puts "To proceed run this task again, and give the following option:"
          puts "i_know_what_i_am_doing=yes"
          raise ArgumentError, "Can't proceed without confirmation."
        end
        flush_rdf
        # We'll get all data from single query.
        fat_rels = TaliaCore::SemanticRelation.find(:all, :joins => fat_record_joins,
        :select => fat_record_select)
        fat_rels.each do |rec|
          subject = N::URI.new(rec.subject_uri)
          predicate = N::URI.new(rec.predicate_uri)
          object = if(rec.object_uri)
            N::URI.new(rec.object_uri)
          else
            rec.property_value
          end
          ActiveRDF::FederationManager.add(subject, predicate, object)
          yield if(block_given?)
        end

        # Rewriting all the "runtime type" rdf triples
        # We'll select the type as something else, so that it doesn't try to do
        # STI instantiation (which would cause this to blow for classes that
        # are defined outside the core.
        TaliaCore::ActiveSource.find(:all, :select => 'uri, type AS runtime_type').each do |src|
          type = (src.runtime_type || 'ActiveSource')
          ActiveRDF::FederationManager.add(src, N::RDF.type, N::TALIA + type)
          yield if(block_given?)
        end
      end

      # The number of triples that would be rewritten with #rewrite_rdf
      def rewrite_count
        TaliaCore::SemanticRelation.count + TaliaCore::ActiveSource.count
      end

      # Load the database fixtures. This "manually" loads the database fixtures for
      # the Talia tables for the core unit tests. The fixtures are those contained
      # in the talia_core folder, _not_ the ones from the application's tests.
      def load_fixtures
        # fixtures = ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/) : Dir.glob(File.join(File.dirname(__FILE__), 'test', 'fixtures', '*.{yml,csv}'))  
        fixtures = [ 'active_sources', 'semantic_relations', 'semantic_properties' 'data_records']
        fixtures.reverse.each { |f| ActiveRecord::Base.connection.execute "DELETE FROM #{f}" }
        fixtures.each do |fixture_file|
          Fixtures.create_fixtures(File.join('test', 'fixtures'), File.basename(fixture_file, '.*'))  
        end  
      end

      # Runs the migrations for the main Talia tables. This will use the migrations from 
      # the "talia" generator, _not_ the ones from the Rails application.
      def do_migrations
        migration_path = File.join("generators", "talia", "templates", "migrations")
        ActiveRecord::Migrator.migrate(migration_path, ENV["VERSION"] ? ENV["VERSION"].to_i : nil )
      end

      # Check if the given flag is set on the command line. This will assert that the flag
      # is set, otherwise it's equivalent to String#yes? (from the core extensions) on 
      # the variable
      def flag?(the_flag)
        assit_not_nil(the_flag)
        ENV[the_flag].yes?
      end

      # SQL select portion selecting "fat" records from the semantic_relatations table. 
      # This will select all data needed to create all triples. Used for rewriting the rdf. 
      def fat_record_select
        select = 'semantic_relations.id AS id, semantic_relations.created_at AS created_at, '
        select << 'semantic_relations.updated_at AS updated_at, '
        select << 'object_id, object_type, subject_id, predicate_uri, '
        select << 'obj_props.created_at AS property_created_at, '
        select << 'obj_props.updated_at AS property_updated_at, '
        select << 'obj_props.value AS property_value, '
        select << 'obj_sources.created_at AS object_created_at, '
        select << 'obj_sources.updated_at AS object_updated_at, obj_sources.type AS  object_realtype, '
        select << 'obj_sources.uri AS object_uri, '
        select << 'subject_sources.uri AS subject_uri'
        select
      end

      # SQL join snippet for selecting "fat" records. See fat_record_select
      def fat_record_joins
        joins =  " LEFT JOIN active_sources AS obj_sources ON semantic_relations.object_id = obj_sources.id AND semantic_relations.object_type = 'TaliaCore::ActiveSource'"
        joins << " LEFT JOIN semantic_properties AS obj_props ON semantic_relations.object_id = obj_props.id AND semantic_relations.object_type = 'TaliaCore::SemanticProperty'"
        joins << " LEFT JOIN active_sources AS subject_sources ON semantic_relations.subject_id = subject_sources.id"
        joins
      end

      # Print the options for the rake tasks to the console.
      def print_options
        puts "\nGeneral options (not all options are valid for all tasks):"
        puts "files=<pattern>     - Files for the task (a pattern to match the files)"
        puts "talia_root=<path>   - Manually configure the TALIA_ROOT path"
        puts "                      (default:autodetect)"
        puts "reset_rdf={yes|no}  - Flush the RDF store (default:no)"
        puts "reset_db={yes|no}   - Flush the database (default:no)"
        puts "config=<filename>   - Talia configuration file (default: talia_core)"
        puts "environment=<env>   - Environment for configuration (default: development)"
        puts "data_dir=<dir>      - Directory for the data files"
        puts "verbose={yes|no}    - Show some additional info"
        puts ""
      end

      # Force-loads all Talia related models. This will attempt to load all classes in
      # RAILS_ROOT/app/models and in TALIA_CODE_ROOT/lib/talia_core/source_types.
      #
      # Use this to make sure the whole hierarchy of ActiveSource subclasses is in memory..
      def load_all_models
        return if @models_loaded
        load_models_from File.join(RAILS_ROOT, 'app', 'models', '**', '*.rb') if(defined? RAILS_ROOT)
        load_models_from File.join(TALIA_CODE_ROOT, 'lib', 'talia_core', 'source_types',  '**',  '*.rb'), 'TaliaCore::SourceTypes::'
        TaliaCore::Source
        TaliaCore::Collection

        @models_loaded = true
      end

      # Helper to load all classes from a given directory. This will attempt to instanciate all 
      # classes found in the dir. The name of the class to be instantiated will be taken from the
      # file name, prepending the prefix (e.g. 'ModuleName::') if set. 
      def load_models_from(dir, prefix='')
        # Appends a file system directory separator to the directory if needed.
        dir = File.join(dir, '')
        Dir[File.join(dir, '**', '*.rb')].each do |f| 
          # For every rb file we try to gues and instantiate the contained class.
          model_name = f.gsub(/#{dir}|\.rb/, '')
          begin
            (prefix + model_name).camelize.constantize
          rescue Exception => e
            # Errors at this point could be ignored, as there may be files that do not contain classes.
            TaliaCore.logger.warn "Could not load class #{(prefix + model_name).camelize}: #{e.message}"
          end
        end
      end

    end
  end
end
