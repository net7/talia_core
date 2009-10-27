class Admin::SourcesController < ApplicationController
  require_role 'admin'
  layout 'admin'
  
  active_scaffold 'TaliaCore::ActiveSource' do |config|
    config.columns = [:uri, :type]
  end

end
