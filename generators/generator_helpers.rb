module GeneratorHelpers
  
  DEFAULT_SHEBANG = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])
  
  def files_in(m, dir, top_dir = '')
    Dir["#{File.join(self_dir, 'templates', dir)}/*"].each do |file|
      
      m.directory "#{top_dir}#{dir}"
      
      if(File.directory?(file))
        files_in(m, "#{dir}/#{File.basename(file)}", top_dir)
      else
        m.file "#{dir}/#{File.basename(file)}", "#{top_dir}#{dir}/#{File.basename(file)}"
      end
    end
  end
  
  def make_migration(m, template_name)
    m.migration_template "migrations/#{template_name}", "db/migrate", :migration_file_name => template_name.gsub(/\.rb\Z/, '')
  end
  
end

# This monkeypatches a problem in the generator that causes it to have 
# migration ids based on the timestamp in seconds. If more than one
# migration is generated at a time (that is, whithin one second), 
# this will cause them to not work because of identical ids.
module Rails
  module Generator
    module Commands
      class Create
        
        alias :orig_migration_string :next_migration_string
        
        def migration_count
          @m_count ||= 0
          @m_count += 1
          @m_count
        end

        def next_migration_string(padding = 3)
          return orig_migration_string(padding) unless(ActiveRecord::Base.timestamped_migrations)
          (Time.now.utc.strftime("%Y%m%d%H%M") + ("%.2d" % migration_count))
        end
        
      end
    end
  end
end