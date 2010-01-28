require File.dirname(__FILE__) + '/../generator_helpers'

class TaliaAdminGenerator < Rails::Generator::Base
  
  include GeneratorHelpers
  
  def self_dir ; File.dirname(__FILE__) ; end
    
  def manifest
    record do |m|
      m.files_in 'views', 'app/'
      m.files_in 'helpers', 'app/'
      m.files_in 'controllers', 'app/'
      m.files_in 'public'
      m.files_in 'test'
      
      m.directory 'app/models'
      m.file 'models/role.rb', 'app/models/role.rb', :collision => :force
      
      m.directory 'db/migrate'
      m.make_migration "populate_users.rb"
    end
  end

end