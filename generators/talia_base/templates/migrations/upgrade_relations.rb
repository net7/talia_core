# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

class UpgradeRelations < ActiveRecord::Migration
  def self.up
    add_column :semantic_relations, :rel_order, :integer, :null => true
    # Preparing to have the values in the same table
    add_column :semantic_relations, :value, :string, :null => true
  end

  def self.down
    remove_column :semantic_relations, :rel_order
    remove_column :semantic_relations, :value
  end
end
