# Rake tasks for the talia core

require 'rake'
require 'yaml'
require 'talia_core'
require 'talia_util'
require 'talia_util/util'
require 'rake/testtask'
require 'progressbar'

include TaliaUtil

namespace :talia_core do

  # Standard initialization
  desc "Initialize the TaliaCore"
  task :init do
    Util::title
    Util::init_talia
    TLoad::force_rails_parts unless(defined?(ActiveRecord))
    Util::talia_config if(Util::flag?('verbose'))
    # Add load paths to allow autoloading of all class from this tasks
    ActiveSupport::Dependencies.load_paths << File.join(TALIA_ROOT, 'lib')
    model_path = File.join(TALIA_ROOT, 'app', 'models')
    ActiveSupport::Dependencies.load_paths << model_path if(File.directory?(model_path))
  end

  # Removes all data
  desc "Reset the Talia data store"
  task :clear_store => :init do
    Util::flush_db
    Util::flush_rdf
    puts "Flushed data store"
  end

  # Init for the unit tests
  desc "Initialize Talia for the tests"
  task :test_setup do
    unless(ENV['environment'])
      puts "Setting environment to 'test'"
      ENV['environment'] = "test"
    end

    # Invoke the init after the setup
    # Rake::Task["talia_core:init"].invoke
  end

  # Test task
  desc 'Test the talia_core plugin.'
  task :test => :test_setup
  # Create the test tasks
  Rake::TestTask.new(:test) do |t| 
    t.libs << 'lib'
    # This will always take the files from the talia_core directory
    t.test_files = FileList["#{File.dirname(__FILE__)}/../../test/**/*_test.rb"]
    t.verbose = true
  end

  desc desc "Xml import. Options: [index=<indexfile>] [xml=<datafile>] [importer=<importclass>] [reset_store=true] [...]"
  task :xml_import => :init do
    importer = TaliaUtil::ImportJobHelper.new(STDOUT, TaliaUtil::BarProgressor)
    importer.do_import
  end

  # Just run the Talia init to test it
  desc "Test the TaliaCore startup"
  task :init_test => :init do
    Util::talia_config
  end

  # Task for importing ontologies/raw RDF data
  desc "Import ontologies. This imports the given rdf files (same as rdf_import), and sets the context automatically"
  task :ontology_import => :init do
    TaliaCore::RdfImport::import(ENV['rdf_syntax'], TaliaUtil::Util::get_files, :auto)
  end

  # RDF importing task. A context can be freely assigned.
  desc "Import RDF data directly into the triple store. Option: rdf_syntax={ntriples|rdfxml} [context=<context>]"
  task :rdf_import => :init do
    TaliaCore::RdfImport::import(ENV['rdf_syntax'], TaliaUtil::Util::get_files, ENV['context'])
  end

  desc "Update the Ontologies. Options [ontologies=<ontology_folder>]"
  task :setup_ontologies => :init do
    Util::setup_ontologies
  end

  # Rewrite your base URL. This will loose any comments in the config file
  desc "Rewrite the database to move it to a new URL. Options new_home=<url>."
  task :move_site => :init do
    new_site = ENV['new_home']
    # Check if this looks like an URL
    raise(RuntimeError, "Illegal new_home given. (It must start with http(s):// and end with a slash)") unless(new_site =~ /^https?:\/\/\S+\/$/)
    # open up the configuration file
    config_file_path = File.join(TALIA_ROOT, 'config', 'talia_core.yml')
    config = YAML::load(File.open(config_file_path))
    old_site = config['local_uri']
    raise(RuntimeError, "Could not determine current local URI") unless(old_site && old_site.strip != '')
    puts "New home URL: #{new_site}"
    puts "Original home URL: #{old_site}"
    # Rewrite the sql database
    ActiveRecord::Base.connection.execute("UPDATE active_sources SET uri = replace(uri, '#{old_site}', '#{new_site}')")
    puts('Updated database, now recreating RDF')
    # Rebuild the RDF
    prog = ProgressBar.new('Rebuilding', Util::rewrite_count)
    Util::rewrite_rdf { prog.inc }
    prog.finish
    # Rebuild the ontologies
    Util::setup_ontologies
    # Write back to the config file
    config['local_uri'] = new_site
    open(config_file_path, 'w') { |io| io.puts(config.to_yaml) }
    puts "New configuration saved. Finished site rebuilding."
  end

  # Task for updating the OWL classes with RDFS class information
  desc "Update OWL classes with RDFS class information."
  task :owl_to_rdfs_update => :init do
    RdfUpdate::owl_to_rdfs
  end

  # Helper task to bootstrap Redland RDF (should usually only be a problem when
  # using Redland with mysql store)
  desc "Initialize Redland RDF store. Option: rdfconf=<rdfconfig_file> [environment=env]"
  task :redland_init do
    # This simply activates the RDF store once with the :new option set.
    Util.title
    environment = ENV['environment'] || "development"
    raise(ArgumentError, "Must have rdfconf=<config_file>") unless(ENV['rdfconf'])
    options = YAML::load(File.open(ENV['rdfconf']))[environment]

    rdf_cfg = Hash.new
    options.each { |key, value| rdf_cfg[key.to_sym] = value }

    rdf_cfg[:new] = "yes"

    ActiveRDF::ConnectionPool.add_data_source(rdf_cfg)
  end

  # Help info
  desc "Help on general options for the TaliaCore tasks"
  task :help do
    Util.title
    puts "Talia Core tasks usage information."
    Util::print_options
  end

  desc "Rebuild the RDF store from the database. Option [hard_reset=(true|false)]"
  task :rebuild_rdf => :init do
    count = TaliaCore::SemanticRelation.count
    puts "Rebuilding RDF for #{count} triples."
    prog = ProgressBar.new('Rebuilding', count)
    Util::rewrite_rdf { prog.inc }
    prog.finish
    puts "Finished rewriting. ATTENTION: You may want to call setup_ontologies now."
  end

  desc "Generate large database for load tests. [count=<number of sources>]"
  task :generate_large_data => :init do
    count = (ENV['count'] || '10000').to_i
    prog = ProgressBar.new('Creating', count)
    (1..count).each do |idx|
      src = TaliaCore::ActiveSource.new(:uri => N::LOCAL + "large_sample_#{idx}")
      if(idx > 1)
        # For now an easy approach: Each source has 10 connections to the previous
        # one.
        prev = TaliaCore::ActiveSource.find(N::LOCAL + "large_sample_#{idx - 1}")
        (1..10).each do |rel_idx|
          src[N::RDF + "dummy_rel_#{rel_idx}"] << prev
          src[N::RDFS + "dummy_prop_#{rel_idx}"] << 'Some property'
        end
      end
      src.save!
      prog.inc
    end
    prog.finish
  end

  # Helper methods

end