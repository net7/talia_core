require File.dirname(__FILE__) + '/../generator_helpers'

class TaliaAdminGenerator < Rails::Generator::Base
  
  include GeneratorHelpers
  
  def self_dir ; File.dirname(__FILE__) ; end
    
  def manifest
    record do |m|
      files_in m, 'views', 'app/'
      files_in m, 'helpers', 'app/'
      files_in m, 'controllers', 'app/'
      files_in m, 'public'
      files_in m, 'test'
    end
  end

end