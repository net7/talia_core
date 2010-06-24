require File.join(File.dirname(__FILE__), '..', 'test_helper')

module TaliaCore
  # Test the RdfReader class.
  class RdfReaderTest < Test::Unit::TestCase

    suppress_fixtures
    
    def setup


      @test_ntriple  = '<http://foodonga.com> <http://bongobongo.com> "foo" .'
      @test_ntriple << '<http://foodonga.com> <http://bongobongo.com> "bar@en" .'
      @test_ntriple << '<http://foodonga.com> <http://bongobongo.com> <http:/bingobongo.com> .'

      @sources = ActiveSourceParts::Rdf::RdfReader.sources_from(@test_ntriples)
    end
    
    def test_sources
      assert_equal(1, @sources.size)
    end
    
    def test_attributes
      assert_kind_of(Hash, @sources.first)
    end
    
    def test_uri
      assert_equal('http://foodonga.com', @sources.first['uri'])
    end
    
    def test_predicate
      assert_equal(['foo', 'bar', '<http:/bingobongo.com>'], @sources.first['http://bongobongo.com'])
    end
    
    def test_i18n_value
      assert_equal('en', @sources.first['http://bongobongo.com'].detect { |el| el == 'bar'}.lang)
    end
    
  end
end
