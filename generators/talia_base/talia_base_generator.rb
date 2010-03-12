require File.dirname(__FILE__) + '/../generator_helpers'

class TaliaBaseGenerator < Rails::Generator::Base
  
  include GeneratorHelpers
  
  def manifest
    
    record do |m|
      # Write the routes. Remember that these end up in the file in the reverse order of the calls
      m.rewrite_file 'config/routes.rb', "map.connect ':controller/:action/:id.:format'", "# map.connect ':controller/:action/:id.:format'"
      m.route "# Default semantic dispatch\n  map.connect ':dispatch_uri.:format', :controller => 'sources', :action => 'dispatch',\n    :requirements => { :dispatch_uri => /[^\\.]+/ }"
      m.route "# Routes for the sources\n  map.resources :sources, :requirements => { :id => /.+/  }"
      m.route "# Routes for types\n  map.resources :types"
      m.route "map.resources :data_records, :controller => 'source_data'"
      m.route "map.connect 'source_data/:type/:location', :controller => 'source_data',\n    :action => 'show_tloc',\n    :requirements => { :location => /[^\\/]+/ } # Force the location to match also filenames with points etc."
      m.route "# Routes for the source data\n  map.connect 'source_data/:id', :controller => 'source_data',\n    :action => 'show'"
      m.route "# Ontologies\n  map.resources :ontologies"
      m.route "# Autocomplete on URI\n  map.connect 'sources/auto_complete_for_uri', :controller => 'sources', :action => 'auto_complete_for_uri'"
      
      # Some initialization stuff
      m.directory 'config/initializers'
      m.file "config/talia_initializer.rb", "config/initializers/talia.rb"
      m.file "talia.sh", "talia.sh", :shebang => '/bin/sh', :chmod => 0755
      m.file "config/warble.rb", "config/warble.rb"
      
      # Install the scripts
      m.directory 'script'
      m.file 'script/configure_talia', 'script/configure_talia', :shebang => DEFAULT_SHEBANG, :chmod => 0755
      m.file 'script/prepare_images', 'script/prepare_images', :shebang => DEFAULT_SHEBANG, :chmod => 0755
      
      # The whole app shebang of files
      m.files_in 'app'
      
      # The default ontologies
      m.files_in 'ontologies'
      
      # The whole public dir
      m.files_in 'public'
      
      # Set up the rake tasks, only if we come from a gem
      if(Gem.source_index.find_name('talia_core').first)
        m.directory 'lib/tasks'
        m.file 'tasks/talia_core.rk', 'lib/tasks/talia_core.rake'
      end
      
      # Add the migrations
      m.directory 'db/migrate'
      m.file "migrations/constraint_migration.rb", "db/migrate/constraint_migration.rb"
      m.make_migration "create_active_sources.rb"
      m.make_migration "create_semantic_relations.rb"
      m.make_migration "create_semantic_properties.rb"
      m.make_migration "create_data_records.rb"
      m.make_migration "create_workflows.rb"
      m.make_migration "create_custom_templates.rb"
      m.make_migration "upgrade_relations.rb"
      m.make_migration "create_progress_jobs.rb"
      
      m.readme 'README'
    end
  end
  
  def self_dir ; File.dirname(__FILE__) ; end
  
end