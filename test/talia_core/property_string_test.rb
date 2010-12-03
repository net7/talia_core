# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require 'test/unit'

# Load the helper class
require File.join(File.dirname(__FILE__), '..', 'test_helper')

module TaliaCore
    class PropertyStringTest < Test::Unit::TestCase
        
      def test_simple_value
        props = PropertyString.parse('value')
        assert_equal('value', props)
        assert_equal(nil, props.lang)
        assert_equal(nil, props.type)
      end
      
      def test_language
        props = PropertyString.parse('value@en')
        assert_equal('value', props)
        assert_equal('en', props.lang)
        assert_equal(nil, props.type)
      end
      
      def test_lang_type
        props = PropertyString.parse('value@en^^string')
        assert_equal('value', props)
        assert_equal('en', props.lang)
        assert_equal('string', props.type)
      end
      
      def test_type_lang
        props = PropertyString.parse('value^^string@en')
        assert_equal('value', props)
        assert_equal('en', props.lang)
        assert_equal('string', props.type)
      end
      
      def test_type
        props = PropertyString.parse('value^^string')
        assert_equal('value', props)
        assert_equal(nil, props.lang)
        assert_equal('string', props.type)
      end
      
      def test_type_no_val
        props = PropertyString.parse('^^string')
        assert_equal('', props)
        assert_equal(nil, props.lang)
        assert_equal('string', props.type)
      end
      
      def test_lang_no_val
        props = PropertyString.parse('@en')
        assert_equal('', props)
        assert_equal('en', props.lang)
        assert_equal(nil, props.type)
      end
      
      def test_lang_type_no_val
        props = PropertyString.parse('@en^^string')
        assert_equal('', props)
        assert_equal('en', props.lang)
        assert_equal('string', props.type)
      end
      
      def test_to_rdf
        props = PropertyString.parse('value^^string@en')
        assert_equal('value^^string@en', props.to_rdf)
        assert_equal('value', props)
      end
      
      def test_to_rdf_lang_with_new
        props = PropertyString.new('value', 'en')
        assert_equal('value@en', props.to_rdf)
        assert_equal('value', props)
      end
      
    end
end