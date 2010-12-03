# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

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
      setup_once(:flush) do
        TaliaUtil::Util.flush_rdf
        true
      end
      
      setup_once(:test_xml) do
        File.open(TestHelper.fixture_file('generic_test.xml')) { |io| io.read }
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
      
      setup_once(:reader_fs) do
        GenericImporterTest.new(@test_xml)
      end
      
      setup_once(:reader_net) do
        reader = GenericImporterTest.new(@test_xml)
        reader.base_file_url = 'http://www.talia.org/foobar/moff'
        reader
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
    
    def test_absolute_url_absolute
      assert_equal('/file', @reader_fs.send(:get_absolute_file_url, '/file'))
    end
    
    def test_absolute_url_relative
      assert_equal(File.join(TALIA_ROOT, 'file'), @reader_fs.send(:get_absolute_file_url, 'file'))
    end
    
    def test_absolute_net_url_on_fs
      assert_equal('http://foobar.com/', @reader_fs.send(:get_absolute_file_url, 'http://foobar.com/'))
    end
    
    def test_absolute_net_url
      assert_equal('http://foobar.com/', @reader_net.send(:get_absolute_file_url, 'http://foobar.com/'))
    end
    
    def test_relative_net_path
       assert_equal('http://www.talia.org/foobar/file', @reader_net.send(:get_absolute_file_url, 'file'))
    end
    
    def test_absolute_net_path
       assert_equal('http://www.talia.org/file', @reader_net.send(:get_absolute_file_url, '/file'))
    end
    
    def test_file_url_on_net_absolute
      assert_equal('/test/file', @reader_net.send(:get_absolute_file_url, 'file:///test/file'))
    end
    
    def test_file_url_on_net_relative
      assert_equal('test/file', @reader_net.send(:get_absolute_file_url, 'file://test/file'))
    end
    
    # def test_create
    #   assert(@source_objects)
    # end
    
  end
end