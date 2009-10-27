class Admin::UsersController < ApplicationController
  require_role 'admin'
  layout 'admin'
  
  active_scaffold :user do |config|
    config.columns = [:login, :name, :email, :password, :password_confirmation, :roles]
    list.columns.exclude :password, :password_confirmation
  end
  
end
