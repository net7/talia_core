# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require File.dirname(__FILE__) + '/../generator_helpers'

class TaliaAdminGenerator < Rails::Generator::Base
  
  include GeneratorHelpers
  
  def self_dir ; File.dirname(__FILE__) ; end
    
  def manifest
    record do |m|
      m.gem_dependency 'hobo'
      m.route 'Hobo.add_routes(map)'
      m.route "map.admin '/admin', :controller => 'admin/front', :action => 'index'"
      m.route "map.site_search  'search', :controller => 'admin/front', :action => 'search'"
      m.file 'config/hobo_initializer.rb', 'config/initializers/hobo.rb'
      m.files_in 'app'
      m.files_in 'public'
      m.files_in 'test'
      
      m.directory 'db/migrate'
      m.make_migration "create_users.rb"
    end
  end

end