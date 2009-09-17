class TaliaMigrationsGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.file "constraint_migration.rb", "db/migrate/constraint_migration.rb" 
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
  
  def make_migration(m, template_name)
    m.migration_template template_name, "db/migrate", :migration_file_name => template_name.gsub(/\.rb\Z/, '')
  end
  
end