# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require File.join(File.dirname(__FILE__), '..', 'test_helper')

module TaliaCore

  # Test the Generic Xml Import
  class ImportJobHelperTest < Test::Unit::TestCase
    
    def setup
      setup_once(:flush) { TestHelper::flush_store }
      
      setup_once(:imported) do
        ENV['xml'] = TestHelper.fixture_file('xml_test.xml')
        importer = TaliaUtil::ImportJobHelper.new
        importer.do_import
        ActiveSource.find('http://xml_test/from_file')
      end

      setup_once(:rdf_ntriples_imported) do
        ENV['xml'] = TestHelper.fixture_file('rdf_test.nt')
        ENV['importer'] = 'TaliaCore::ActiveSourceParts::Rdf::NtriplesReader'
        importer = TaliaUtil::ImportJobHelper.new
        importer.do_import
        ActiveSource.find('http://foodonga.com')
      end

    end
    
    def test_import_success
      assert(@imported)
    end
    
    def test_property
      assert_property(@imported['http://localnode.org/localthi'], 'value')
    end
    
    def test_relation
      assert_property(@imported[N::RDF.relatit], SourceTypes::DummySource.new('http://localnode.org/as_create_attr_dummy_2'), SourceTypes::DummySource.new('http://localnode.org/as_create_attr_dummy_1'))
    end

    def test_ntriples_success
      assert(@rdf_ntriples_imported)
    end

    def test_ntriples_property
      assert_property(@rdf_ntriples_imported['http://bongobongo.com'], 'foo', 'bar', N::URI.new('http://bingobongo.com'))
    end

  end
end
