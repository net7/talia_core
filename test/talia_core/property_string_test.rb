require 'test/unit'

# Load the helper class
require File.join(File.dirname(__FILE__), '..', 'test_helper')

module TaliaCore
    class PropertyStringTest < Test::Unit::TestCase
        
      def test_simple_value
        props = PropertyString.new('value')
        assert_equal('value', props)
        assert_equal(nil, props.lang)
        assert_equal(nil, props.type)
      end
      
      def test_language
        props = PropertyString.new('value@en')
        assert_equal('value', props)
        assert_equal('en', props.lang)
        assert_equal(nil, props.type)
      end
      
      def test_lang_type
        props = PropertyString.new('value@en^^string')
        assert_equal('value', props)
        assert_equal('en', props.lang)
        assert_equal('string', props.type)
      end
      
      def test_type_lang
        props = PropertyString.new('value^^string@en')
        assert_equal('value', props)
        assert_equal('en', props.lang)
        assert_equal('string', props.type)
      end
      
      def test_type
        props = PropertyString.new('value^^string')
        assert_equal('value', props)
        assert_equal(nil, props.lang)
        assert_equal('string', props.type)
      end
      
      def test_type_no_val
        props = PropertyString.new('^^string')
        assert_equal('', props)
        assert_equal(nil, props.lang)
        assert_equal('string', props.type)
      end
      
      def test_lang_no_val
        props = PropertyString.new('@en')
        assert_equal('', props)
        assert_equal('en', props.lang)
        assert_equal(nil, props.type)
      end
      
      def test_lang_type_no_val
        props = PropertyString.new('@en^^string')
        assert_equal('', props)
        assert_equal('en', props.lang)
        assert_equal('string', props.type)
      end
      
    end
end