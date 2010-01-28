module GeneratorHelpers

  DEFAULT_SHEBANG = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])

  # This is more of a quick hack, but the functionality requires extra plugins
  # and by installing them from the generator everything can be done with
  # one single command
  def install_plugin(plugin_url)
    system("#{ruby_bin} #{plugin_script} install #{plugin_url}")
  end

  # Path to the plugin (installer) script
  def plugin_script
    @plugin_script ||= File.join(RAILS_ROOT, 'script', 'plugin')
  end

  # Path to the ruby binary that we're currently using
  def ruby_bin
    @ruby_bin ||= begin
      c = ::Config::CONFIG
      File.join(c['bindir'], c['ruby_install_name']) << c['EXEEXT']
    end
  end
  
end

module CreatorHelpers
  def files_in(dir, top_dir = '')
    Dir["#{File.join(self_dir, 'templates', dir)}/*"].each do |file|

      directory "#{top_dir}#{dir}"

      if(File.directory?(file))
        files_in("#{dir}/#{File.basename(file)}", top_dir)
      else
        file "#{dir}/#{File.basename(file)}", "#{top_dir}#{dir}/#{File.basename(file)}"
      end
    end
  end

  def make_migration(template_name)
    migration_template "migrations/#{template_name}", "db/migrate", :migration_file_name => template_name.gsub(/\.rb\Z/, '')
  end
  
  def route(route)
    sentinel = 'ActionController::Routing::Routes.draw do |map|'
    logger.route route
    gsub_file 'config/routes.rb', /(#{Regexp.escape(sentinel)})/mi do |m|
      "#{m}\n\n  #{route}\n"
    end
  end
end

module DestructorHelpers
  
  def route(route)
    logger.remove_route route
    to_remove = "\n\n  #{route}"
    gsub_file 'config/routes.rb', /(#{to_remove})/mi, ''
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
        
        include CreatorHelpers
        
        alias :orig_migration_string :next_migration_string

        def migration_xtime
          @migration_xtime ||= Time.now
        end

        def migration_time
          @migration_time ||= migration_xtime.utc.strftime('%Y%m%d%H%M')
        end

        def migration_count
          @m_count ||= begin
            Dir.glob("#{RAILS_ROOT}/#{@migration_directory}/#{migration_time}*.rb").inject(migration_xtime.sec) do |max, file|
              n = File.basename(file)[12..13].to_i
              (n > max) ? n : max
            end
          end
          @m_count += 1
          @m_count
        end

        def next_migration_string(padding = 3)
          return orig_migration_string(padding) unless(ActiveRecord::Base.timestamped_migrations)
          migration_time + ("%.2d" % migration_count)
        end

      end

      class Destroy
        include DestructorHelpers
      end

    end
  end
end