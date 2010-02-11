require File.join(File.dirname(__FILE__), '..', 'test_helper')
require 'rexml/document'

module TaliaUtil

  # Test the Generic Xml Import
  class RdfBuilderTest < Test::Unit::TestCase
    
    def setup
      @my_xml = ''
      @my_builder = Xml::RdfBuilder.send(:new, :target => @my_xml, :indent => 2)
    end
    
    def test_make_namespace
      pred_uri = URI.parse('http://www.foobar.com/bar/moo')
      namespace = @my_builder.send(:make_namespace, pred_uri)
      assert_equal('foobar', namespace)
    end
    
    def test_make_namespace_multi
      pred_uri = URI.parse('http://www.foobar.com/bar/moo')
      pred_uri_2 = URI.parse('http://www.foobar.com/bar/foo')
      pred_uri_3 = URI.parse('http://www.foobar.com/bar/boo')
      @my_builder.send(:make_namespace, pred_uri)
      @my_builder.send(:make_namespace, pred_uri)
      @my_builder.send(:make_namespace, pred_uri_2)
      namespace = @my_builder.send(:make_namespace, pred_uri_3)
      assert_equal('foobar3', namespace)
    end

    
    def test_make_predicate_namespace_hash
      predspace = @my_builder.send(:make_predicate_namespace, 'http://www.foobar.com/bar/moo#first')
      assert_equal('foobar:first', predspace)
      predspace = @my_builder.send(:make_predicate_namespace, 'http://www.foobar.com/bar/moo#second')
      assert_equal('foobar:second', predspace)
    end
    
    def test_make_predicate_namespace_slash
      predspace = @my_builder.send(:make_predicate_namespace, 'http://www.foobar.com/bar/moo/first')
      assert_equal('foobar:first', predspace)
      predspace = @my_builder.send(:make_predicate_namespace, 'http://www.foobar.com/bar/moo/second')
      assert_equal('foobar:second', predspace)
    end
    
    def test_make_predicate_namespace_multi
      predspace = @my_builder.send(:make_predicate_namespace, 'http://www.foobar.com/bar/moo/first')
      assert_equal('foobar:first', predspace)
      predspace = @my_builder.send(:make_predicate_namespace, 'http://www.foobar.com/bar/moo#first')
      assert_equal('foobar2:first', predspace)
      predspace = @my_builder.send(:make_predicate_namespace, 'http://www.foobar.com/bar/moo#second')
      assert_equal('foobar2:second', predspace)
      predspace = @my_builder.send(:make_predicate_namespace, 'http://www.foobar.com/bar/moo/second')
      assert_equal('foobar:second', predspace)
      predspace = @my_builder.send(:make_predicate_namespace, 'http://www.foobar.com/bar/boo/first')
      assert_equal('foobar3:first', predspace)
    end
    
    def test_prepare_triples
      triple_hash = @my_builder.send(:prepare_triples, test_triples)
      assert_equal({ 
        N::LOCAL.foobar.to_s => { N::URI.new('foobar:first') => ['worksit', 'worksit2'] }, 
        N::TALIA.whatever.to_s => { 
          N::URI.new('talia:predicate') => [ N::URI.new('http://www.barbaa.com/fun') ], 
          N::URI.new('foobar2:first') => [ N::URI.new('http://www.barbaa.com/fun') ]  
        }
      }, triple_hash)
    end
    
    def test_open_for_triples
      xml = Xml::RdfBuilder.xml_string_for_triples(test_triples)
      assert_nothing_raised { REXML::Document.new(xml) }
    end
    
    private
    
    def test_triples
      [
        [ N::LOCAL.foobar, 'http://www.foobar.com/bar/moo/first', "worksit"],
        [ N::LOCAL.foobar, 'http://www.foobar.com/bar/moo/first', "worksit2"],
        [ N::TALIA.whatever, N::TALIA.predicate, N::URI.new('http://www.barbaa.com/fun')],
        [ N::TALIA.whatever, 'http://www.foobar.com/bar/moo#first', N::URI.new('http://www.barbaa.com/fun')]
      ]
    end
    
  end
end