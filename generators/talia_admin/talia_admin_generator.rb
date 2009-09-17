class TaliaAdminGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      files_in m, 'views', 'app/'
      files_in m, 'helpers', 'app/'
      files_in m, 'controllers', 'app/'
      files_in m, 'public'
      files_in m, 'test'
    end
  end

  def files_in(m, dir, top_dir = '')
    Dir["#{File.join(File.dirname(__FILE__), 'templates', dir)}/*"].each do |file|
      
      if(File.directory?(file))
        m.directory "#{top_dir}#{dir}/#{File.basename(file)}"
        files_in(m, "#{dir}/#{File.basename(file)}", top_dir)
      else
        m.file "#{dir}/#{File.basename(file)}", "#{top_dir}#{dir}/#{File.basename(file)}"
      end
    end
  end

end