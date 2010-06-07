class TaliaCollection < ActiveRecord::Base
  hobo_model # Don't put anything above this
  
  include DefaultPermissions
  include FakeSource
  extend FakeSource::ClassMethods
  
  has_real_class TaliaCore::Collection
  
  self.inheritance_column = 'foo'
  
  fields do
    uri :string
  end
  
  set_table_name "active_sources"
  
end