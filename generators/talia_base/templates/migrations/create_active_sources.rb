# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

class CreateActiveSources < ActiveRecord::Migration
  def self.up
    create_table :active_sources do |t|
      t.timestamps
      t.string :uri, :null => false
      t.string :type
    end
    
    add_index :active_sources, :uri, :unique => true
  end

  def self.down
    drop_table :active_sources
  end
end
