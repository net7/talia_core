# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

class OaiController < ApplicationController
  def index
    # Remove controller and action from the options.  Rails adds them automatically.
    options = params.delete_if { |k,v| %w{controller action}.include?(k) }
    provider = TaliaOaiProvider.new
    response =  provider.process_request(options)
    render :text => response, :content_type => 'text/xml'
  end
end
