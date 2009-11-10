require File.join(File.dirname(__FILE__), '..', 'test_helper')
require 'bj'

module TaliaCore

  # Test the Generic Xml Import
  class ImportJobHelperTest < Test::Unit::TestCase
    
    def setup
      setup_once(:flush) { TestHelper::flush_store }
      
      setup_once(:job) do
        Bj::Table::Job.delete_all
        Bj::Table::Job.new.save
        job = Bj::Table::Job.find(:first)
        ENV['JOB_ID'] = job.id.to_s
        job
      end
      
      setup_once(:imported) do
        ENV['xml'] = TestHelper.fixture_file('xml_test.xml')
        importer = TaliaUtil::ImportJobHelper.new
        importer.do_import
        ActiveSource.find('http://xml_test/from_file')
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
    
  end
end