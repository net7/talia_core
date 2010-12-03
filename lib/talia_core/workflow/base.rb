# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require File.join('talia_core', 'workflow')

module TaliaCore
  module Workflow
    # Workflow Record class.
    class Base < ActiveRecord::Base
    
      set_table_name 'workflows'
      belongs_to :source
    
      include TaliaCore::Workflow
    
    end
  end
end