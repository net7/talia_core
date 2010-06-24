#http://m.onkey.org/2010/1/22/active-record-query-interface

require File.join(File.dirname(__FILE__), '..', 'test_helper')

module TaliaCore

  # Test the ActiveSource
  class ActiveSourceFinderInterfaceTest < ActiveSupport::TestCase
    fixtures :active_sources, :semantic_properties, :semantic_relations, :data_records
    
     
    def setup
      setup_once(:test_file) { File.join(ActiveSupport::TestCase.fixture_path, 'generic_test.xml') }
      setup_once(:default_sources) do
        raise NotImplementedError
      end
    end
    
    def test_where
      #result = ActiveSource.find(:all, :find_through => ['http://testvalue.org/pred_find_through', active_sources(:find_through_target).uri])
      result = ActiveSource.where('http://testvalue.org/pred_find_through' => active_sources(:find_through_target).uri)
      assert_equal(1, result.size)
      assert_equal(active_sources(:find_through_test), result[0])
    end
    
    
    
  end
  
end
