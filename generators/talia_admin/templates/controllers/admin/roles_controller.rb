class Admin::RolesController < ApplicationController
  require_role 'admin'
  layout 'admin'
  
  active_scaffold :role do |config|
    # config.columns[:users].association.reverse = :user
  end
end
