# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require File.dirname(__FILE__) + '/../generator_helpers'

class TaliaOaiGenerator < Rails::Generator::Base
  
  include GeneratorHelpers
  
  def self_dir ; File.dirname(__FILE__) ; end
    
  def manifest
    record do |m|
      m.directory 'config/initializers'
      m.file "oai_initializer.rb", "config/initializers/talia_oai.rb"
      m.directory 'app/controllers'
      m.file 'oai_controller.rb', 'app/controllers/oai_controller.rb'
      m.route "map.resources :oai"
    end
  end

end