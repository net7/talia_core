require File.dirname(__FILE__) + '/../generator_helpers'

class TaliaBaseGenerator < Rails::Generator::Base
  
  include GeneratorHelpers
  
  def manifest
    puts "Trying to install the plugins before generation"
    plugin_script = File.join(RAILS_ROOT, 'script', 'plugin')
    c = ::Config::CONFIG
    ruby = File.join(c['bindir'], c['ruby_install_name']) << c['EXEEXT']
    
    system("#{ruby} #{plugin_script} install git://github.com/activescaffold/active_scaffold.git")
    system("#{ruby} #{plugin_script} install git://github.com/timcharper/role_requirement.git")
    
    record do |m|
      # Some initialization stuff
      m.directory 'config/initializers'
      m.file "config/talia_initializer.rb", "config/initializers/talia.rb"
      m.file "config/routes.rb", "config/routes.rb", :collision => :ask
      m.file "talia.sh", "talia.sh", :shebang => '/bin/sh', :chmod => 0755
      
      # Install the scripts
      m.directory 'script'
      m.file 'script/configure_talia', 'script/configure_talia', :shebang => DEFAULT_SHEBANG, :chmod => 0755
      m.file 'script/prepare_images', 'script/prepare_images', :shebang => DEFAULT_SHEBANG, :chmod => 0755
      
      # The whole app shebang of files
      files_in m, 'app'
      
      # The default ontologies
      files_in m, 'ontologies'
      
      # Set up the rake tasks, only if we come from a gem
      if(Gem.source_index.find_name('talia_core').first)
        m.directory 'lib/tasks'
        m.file 'tasks/talia_core.rk', 'lib/tasks/talia_core.rake'
      end
      
      # Add the migrations
      m.directory 'db/migrate'
      m.file "migrations/constraint_migration.rb", "db/migrate/constraint_migration.rb"
      make_migration m, "create_sessions.rb"
      make_migration m, "create_users.rb"
      make_migration m, "create_open_id.rb"
      make_migration m, "create_roles.rb"
      make_migration m, "populate_users.rb"
      make_migration m, "create_active_sources.rb"
      make_migration m, "create_semantic_relations.rb"
      make_migration m, "create_semantic_properties.rb"
      make_migration m, "create_data_records.rb"
      make_migration m, "create_workflows.rb"
      make_migration m, "create_custom_templates.rb"
      make_migration m, "upgrade_relations.rb"
      make_migration m, "create_progress_jobs.rb"
      make_migration m, "bj_migration.rb"
      
    end
  end
  
  def self_dir ; File.dirname(__FILE__) ; end
  
end