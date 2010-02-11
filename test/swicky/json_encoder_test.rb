require File.join(File.dirname(__FILE__), '..', 'test_helper')
require 'rexml/document'

module Swicky
  
  class JsonEncoderTest < ActiveSupport::TestCase
    
    def setup
      @encoder = JsonEncoder.new(test_triples)
    end
    
    def test_make_predicate_local
      local = @encoder.send(:make_predicate_local, N::TALIA.foobar)
      assert_equal('foobar', local)
      assert_equal({ 'foobar' => { 'uri' => N::TALIA.foobar.to_s, 'valueType' => 'item' } }, @encoder.instance_variable_get(:@properties_hash))
    end
    
    def test_make_predicate_local_multi
      @encoder.send(:make_predicate_local, N::TALIA.foobar)
      @encoder.send(:make_predicate_local, N::LOCAL.foobar)
      @encoder.send(:make_predicate_local, N::TALIA.foobar)
      local = @encoder.send(:make_predicate_local, N::RDF.foobar)
      assert_equal('foobar3', local)
    end
    
    def test_make_type_local
      local = @encoder.send(:make_type_local, N::TALIA.Foobar)
      assert_equal('Foobar', local)
      assert_equal({ 'Foobar' => { 'uri' => N::TALIA.Foobar.to_s } }, @encoder.instance_variable_get(:@types_hash))
    end
    
    def test_build_item
      item = @encoder.send(:build_item, N::LOCAL.Foo, {
        N::RDF.type => [ N::TALIA.Foobar ],
        N::TALIA.hasIt => ['blarg', 'bar'],
        N::TALIA.strangeThing => ['what'],
        'label' => 'bar'
      })
      assert_equal([{
        'uri' => N::LOCAL.Foo.to_s,
        'type' => [ 'Foobar' ],
        'label' => 'bar',
        'hasIt' => ['blarg', 'bar'],
        'strangeThing' => 'what'
      }], item)
    end
    
    def test_to_json
      assert_equal(expected_result.to_json, @encoder.to_json)
    end
    
    private
    
    def expected_result
      {
        "items" => [
          {
            "uri"=>N::LOCAL.foobar.to_s, 
            "type"=>["MyType"], 
            "label"=>"foobar",
            "first"=>["worksit", "worksit2"]
          }, 
          {
            "uri"=>N::TALIA.whatever.to_s, 
            "type"=>["Resource"], 
            "label"=>"whatever",
            "predicate"=>"The cool thing", 
            "first2"=>"The cool thing"
          },
          {
            "uri"=>"http://www.barbaa.com/fun",
            "type"=>["Resource"],
            "label"=>"The cool thing",
            "predicate"=>"whatever"
          }
        ], 
        "types" => {
          "MyType"=>
          {
            "uri"=>N::TALIA.MyType.to_s
          }, 
          "Resource"=> {
            "uri"=>"http://www.w3.org/1999/02/22-rdf-syntax-ns#Resource"
          }
        }, 
        "properties"=> {
          "first"=> {
            "uri"=>"http://www.foobar.com/bar/moo/first", 
            "valueType"=>"item"
          }, 
          "predicate"=>{
            "uri"=>N::TALIA.predicate.to_s, 
            "valueType"=>"item"
          }, 
          "first2"=>{
            "uri"=>"http://www.foobar.com/bar/moo#first", "valueType"=>"item"
          }
        }
      }
    end
    
    
    def test_triples
      [
        [ N::LOCAL.foobar, 'http://www.foobar.com/bar/moo/first', "worksit"],
        [ N::LOCAL.foobar, 'http://www.foobar.com/bar/moo/first', "worksit2"],
        [ N::LOCAL.foobar, N::RDF.type, N::TALIA.MyType ],
        [ N::TALIA.whatever, N::TALIA.predicate, N::URI.new('http://www.barbaa.com/fun')],
        [ N::TALIA.whatever, 'http://www.foobar.com/bar/moo#first', N::URI.new('http://www.barbaa.com/fun')],
        [ "http://www.barbaa.com/fun".to_uri, N::RDFS.label, "The cool thing"],
        [ "http://www.barbaa.com/fun".to_uri, N::TALIA.predicate, N::TALIA.whatever]
      ]
    end
  end
  
end