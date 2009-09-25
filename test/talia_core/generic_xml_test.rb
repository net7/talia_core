require File.join(File.dirname(__FILE__), '..', 'test_helper')

module TaliaCore

  class GenericImporterTest < ActiveSourceParts::Xml::GenericReader
    element :test_a do 
      add :type, TaliaCore::ActiveSource
      add :uri, from_attribute(:url)
      add N::TALIA.some_value, from_element(:valuator)
      add_rel N::TALIA.some_reference, from_element(:refigator)
    end
    
    plain_element :dummything do
      add_source :test_b do
        add :uri, from_element(:url)
        add :type, from_attribute(:type)
        add_part :test_a
        add_part :test_c do 
          add :uri, from_attribute(:url)
          add :type, TaliaCore::ActiveSource
        end
      end
    end
    
  end

  # Test the Generic Xml Import
  class GenericXmlTest < Test::Unit::TestCase
    
    def setup
      setup_once(:test_xml) do
        File.open(File.join(File.dirname(__FILE__), '..', 'fixtures', 'generic_test.xml')) { |io| io.read }
      end
      setup_once(:imported) do
        GenericImporterTest.sources_from(@test_xml)
      end
      setup_once(:sources) do
        sources = {}
        @imported.each do |el| 
          assert(el['uri'])
          sources[el['uri']] = el
        end
        sources
      end
      # setup_once(:source_objects) do 
      #   ActiveSource.create_from_xml(@test_xml, "TaliaCore::GenericImporterTest")
      # end
    end
    
    def test_import_success
      assert(@imported)
      assert_equal(@imported.size, @sources.size)
    end
    
    def test_uris
      expected = ['http://fooobar.com', 'http://www.otherfoo.com/', 'http://first_sub/X', 'http://first_sub/Y']
      assert_equal(expected.sort, @sources.keys.sort)
    end
    
    def test_simple_reference
      assert_equal(['<http://www.refthing.com/>'], @sources['http://fooobar.com'][N::TALIA.some_reference.to_s] )
    end
    
    def test_type
      assert_equal('TaliaCore::Source', @sources['http://www.otherfoo.com/']['type'])
    end
    
    def test_part
      assert_equal(['<http://www.otherfoo.com/>'], @sources['http://first_sub/Y'][N::TALIA.part_of.to_s])
    end
    
    # def test_create
    #   assert(@source_objects)
    # end
    
  end
end