class CustomTemplate < ActiveRecord::Base
  hobo_model # Don't put anything above this
  
  validates_presence_of :name, :content
  validates_format_of :template_type, :with => /css|xslt/
  
  fields do
    name :string
    template_type :string
    content :text
  end
  
  def create_permitted?
    acting_user.administrator?
  end
  
  def destroy_permitted?
    acting_user.administrator?
  end
  
  def update_permitted?
    acting_user.administrator?
  end
  
  def view_permitted?(field)
    true
  end
end
