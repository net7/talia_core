# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require 'test/unit'

# Load the helper class
require File.join(File.dirname(__FILE__), '..', '..', 'test_helper')


module TaliaCore
  
  class WorkflowBaseTest < Test::Unit::TestCase
  
    def test_initial_state_value
      assert_raise(NoMethodError) {TaliaCore::Workflow::Base.initial_state}
    end
      
    def test_column_was_set
      assert_raise(NoMethodError) {TaliaCore::Workflow::Base.state_column}
    end
    
  end

end