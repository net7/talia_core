# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

# Class for custom templates (e.g. css and xslt). Mainly created for customization in the
# Discovery project. May need a major rework prior of being generally useful.
class CustomTemplate < ActiveRecord::Base # :nodoc:
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
