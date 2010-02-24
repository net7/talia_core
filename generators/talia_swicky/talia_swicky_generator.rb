require File.dirname(__FILE__) + '/../generator_helpers'

class TaliaSwickyGenerator < Rails::Generator::Base
  
  include GeneratorHelpers
  
  def self_dir ; File.dirname(__FILE__) ; end
    
  def manifest
    record do |m|
      m.files_in 'app'
      m.files_in 'test'
      m.route "map.connect 'swicky_notebooks/context/:action', :controller => 'swicky_notebooks'"
      m.route "map.resources :swicky_notebooks, :path_prefix => 'users/:user_name'"
    end
  end

end