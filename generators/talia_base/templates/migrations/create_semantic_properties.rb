# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

class CreateSemanticProperties < ActiveRecord::Migration
  def self.up
    create_table :semantic_properties do |t|
      t.timestamps
      t.text :value, :null => false
    end
    
    # add_index :semantic_properties, :value, :unique => false
  end

  def self.down
    drop_table :semantic_properties
  end
end
