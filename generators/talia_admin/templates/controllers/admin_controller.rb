class AdminController < ApplicationController
  require_role 'admin'

  def index
  end
  
end
