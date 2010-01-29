class TaliaSource < ActiveRecord::Base
  hobo_model # Don't put anything above this
  
  self.inheritance_column = 'foo'
  
  fields do
    uri :string
    type :string
  end
  
  set_table_name "active_sources"
  
  def create_permitted?
    acting_user.administrator?
  end
  
  def update_permitted?
    acting_user.administrator?
  end
  
  def view_permitted?(field)
    true
  end

  def name
    real_source.respond_to?(:label) ? real_source.label : to_uri.to_name_s
  end
  
  def short_type
    self.type ? self.type.gsub('TaliaCore::', '') : 'ActiveSource'
  end
  
  def to_uri
    N::URI.new(self.uri)
  end

  def real_source
    @real_source ||= TaliaCore::ActiveSource.find(self.id, :prefetch_relations => true)
  end
  
  

end
