require File.join(File.dirname(__FILE__), '..', 'test_helper')

module TaliaCore
  class IoTester
    include TaliaUtil::IoHelper
  end
  
  # Test the Generic Xml Import
  class IoHelperTest < Test::Unit::TestCase
    
    def setup
      setup_once(:io) { IoTester.new }
      setup_once(:self) { File.expand_path(__FILE__) }
      setup_once(:self_dir) { File.dirname(@self) }
    end
    
    def test_file_url
      assert_equal('/test/file', @io.file_url('file:///test/file'))
    end
    
    def test_file_url_not
      assert_equal('http://foobar.com', @io.file_url('http://foobar.com'))
    end
    
    def test_base_for_file
      assert_equal(@self_dir, @io.base_for(@self))
    end
    
    def test_base_for_dir
      assert_equal(@self_dir, @io.base_for(@self_dir))
    end
    
    def test_base_for_uri
      assert_equal(URI.parse('http://foobar.com/foodanga/'), @io.base_for('http://foobar.com/foodanga/'))
    end
    
    def test_base_for_uri_doc
      assert_equal(URI.parse('http://foobar.com/foodanga/'), @io.base_for('http://foobar.com/foodanga/doc.xml'))
    end
    
    # TODO: Actual reader tests missing
    
  end
end