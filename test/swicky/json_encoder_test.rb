# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require File.join(File.dirname(__FILE__), '..', 'test_helper')
require 'rexml/document'

module Swicky
  
  class JsonEncoderTest < ActiveSupport::TestCase
    
    def setup
      @encoder = ExhibitJson::ItemCollection.new(test_triples)
    end
    
    def test_item_label
      fake_item = ExhibitJson::Item.new(N::TALIA.item_label_test, @encoder)
      assert_equal('item_label_test', fake_item.label)
    end
    
    def test_make_id
      fake_item = ExhibitJson::Item.new(N::TALIA.test_make_id, @encoder)
      assert_equal('test_make_id', @encoder.make_id(fake_item))
    end
    
    def test_to_json
      assert_equal(expected_result.to_json, @encoder.to_json)
    end
    
    private
    
    def expected_result
      {
        "items" => [
          {
            "label" => 'toplevel',
            "uri" => "http://toplevel.org/",
            "id" => "toplevel",
            "hash" => "h_d11eb7d2122d6af02a9079d975eaec35",
            "type" => [ "MyType" ]
          },
          { 
            "label"=>"foobar",
            "uri"=>N::LOCAL.foobar.to_s, 
            "id"=>"foobar",
            "hash"=>digest(N::LOCAL.foobar.to_s),
            "type"=>["MyType"], 
            "label"=>"foobar",
            "first"=>["worksit", "worksit2"]
          }, 
          {
            "label"=>"whatever",
            "uri"=>N::TALIA.whatever.to_s, 
            "id"=>"whatever",
            "hash"=>digest(N::TALIA.whatever.to_s),
            "type"=>["Resource"],
            "predicate"=>"fun", 
            "first2"=>"fun"
          },
          {
            "label"=>"The cool thing",
            "uri"=>"http://www.barbaa.com/fun",
            "id"=>"fun",
            "hash"=>digest("http://www.barbaa.com/fun"),
            "type"=>["Resource"],
            "predicate"=>"whatever"
          }
        ], 
        "types" => {
          "MyType"=>
          {
            "label"=>"MyType",
            "uri"=>N::TALIA.MyType.to_s,
            "id"=>"MyType",
            "hash"=>digest(N::TALIA.MyType.to_s)
          }, 
          "Resource"=> {
            "label"=>"Resource",
            "uri"=>"http://www.w3.org/1999/02/22-rdf-syntax-ns#Resource",
            "id"=>"Resource",
            "hash"=>digest("http://www.w3.org/1999/02/22-rdf-syntax-ns#Resource")
          }
        }, 
        "properties"=> {
          "first"=> {
            "label"=>"first",
            "uri"=>"http://www.foobar.com/bar/moo/first", 
            "id"=>"first",
            "hash"=>digest("http://www.foobar.com/bar/moo/first"),
            "valueType"=>"text"
          }, 
          "predicate"=>{
            "label"=>"predicate",
            "uri"=>N::TALIA.predicate.to_s, 
            "id"=>"predicate",
            "hash"=>digest(N::TALIA.predicate.to_s),
            "valueType"=>"item"
          }, 
          "first2"=>{
            "label"=>"first",
            "uri"=>"http://www.foobar.com/bar/moo#first", 
            "id"=>"first2",
            "hash"=>digest("http://www.foobar.com/bar/moo#first"),
            "valueType"=>"item"
          }
        }
      }
    end
    
    
    def digest(value)
      ('h_' << Digest::MD5.hexdigest(value))
    end
    
    def test_triples
      [
        [ 'http://toplevel.org/', N::RDF.type, N::TALIA.MyType ],
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