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
        ENV['importer'] = 'TaliaCore::ActiveSourceParts::Rdf::RdfReader'
        importer = TaliaUtil::ImportJobHelper.new
        importer.do_import
        ActiveSource.find('http://rdf_test/from_file')
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

    def test_rdf_success
      assert(@rdf_ntriples_imported)
    end

    def test_rdf_property
      assert_property(@rdf_ntriples_imported['http://localnode.org/localthi'], 'value')
    end

  end
end
