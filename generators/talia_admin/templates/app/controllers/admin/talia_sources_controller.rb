# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

class Admin::TaliaSourcesController < Admin::AdminSiteController
  
  hobo_model_controller
  
  auto_actions :all
  
  def show
    @talia_source = find_instance
    @real_source = @talia_source.real_source
    @property_names = @real_source.direct_predicates
    @properties = {}
    @property_names.each do |pred|
      @properties[pred.to_s] = @real_source[pred]
    end
  end
  
end