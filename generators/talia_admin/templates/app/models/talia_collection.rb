# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

class TaliaCollection < ActiveRecord::Base
  hobo_model # Don't put anything above this
  
  include FakeSource
  extend FakeSource::ClassMethods
  
  has_real_class TaliaCore::Collection
  
  self.inheritance_column = 'foo'
  
  fields do
    uri :string
  end
  
  set_table_name "active_sources"

  def create_permitted?
    acting_user.administrator?
  end

  def update_permitted?
    acting_user.administrator?
  end

  def destroy_permitted?
    acting_user.administrator?
  end

  def view_permitted?(field)
    true
  end
end
