class TaliaCollection < ActiveRecord::Base
  hobo_model # Don't put anything above this
  
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
  
  def view_permitted?(field)
    true
  end
  
  def self.new(*args)
    new_thing = super(*args)
    new_thing[:type] = "TaliaCore::Collection"
    new_thing
  end
  
  def self.find(*args)
    puts args.inspect
    result = TaliaCore::Collection.find(*args)
    if(result.is_a?(Array))
      result.collect { |s| from_real_collection(s) }
    else
      from_real_collection(result)
    end
  end
  
  def self.count(*args)
    TaliaCore::Collection.count(*args)
  end
  
  def name 
    N::URI.new(self.uri).to_name_s
  end
  
  private
  
  def self.from_real_collection(real_collection)
    TaliaCollection.send(:instantiate, real_collection.attributes)
  end
  
end