# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require File.join(File.dirname(__FILE__), '..', 'test_helper')

module TaliaCore
  class LodRdfBuilderTest < Test::Unit::TestCase
    def setup
      setup_once(:flush) { TestHelper::flush_store }
      setup_once(:backlinked_source) do
        backlinked_source = Source.new "http://test.example.org/backlinked"
        backlinked_source["http://test.example.org/attribute1"] = "Attribute One"
        backlinked_source["http://test.example.org/attribute2"] = "Attribute Two"
        backlinked_source.save!
        backlinked_source
      end
      setup_once(:simple_source) do
        simple_source = Source.new "http://test.example.org/simple"
        simple_source["http://test.example.org/attribute3"] = "Attribute Three"
        simple_source["http://test.example.org/attribute4"] = "Attribute Four"
        simple_source["http://test.example.org/attribute5"] = "Attribute Five"
        simple_source["http://test.example.org/link"] = @backlinked_source
        simple_source.save!
        simple_source
      end
      setup_once(:related_source) do
        creator1 = Source.new "http://test.example.org/creator1"
        creator1["http://test.example.org/name"] = "Creator One"
        creator1.save!
        creator2 = Source.new "http://test.example.org/creator2"
        creator2["http://test.example.org/name"] = "Creator Two"
        creator2.save!
        publisher1 = Source.new "http://test.example.org/publisher1"
        publisher1["http://test.example.org/name"] = "Publisher One"
        publisher1.save!
        related_source = SourceTypes::DcResource.new "http://test.example.org/resource1"
        related_source["http://test.example.org/name"] = "Related Source"
        related_source.creators << creator1 << creator2
        related_source.publishers << publisher1
        related_source.save!
        related_source
      end
    end

    def test_simple_lod_rdf
      expected = "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema#\" xmlns:rdfs=\"http://www.w3.org/2000/01/rdf-schema#\" xmlns:owl=\"http://www.w3.org/2002/07/owl#\" xmlns:local=\"http://localnode.org/\" xmlns:talia=\"http://talia.discovery-project.eu/wiki/TaliaInternal#\" xmlns:test=\"http://testnamespace.com/\" xmlns:foo=\"http://foo.com/\" xmlns:hyper=\"http://www.hypernietzsche.org/ontology/\" xmlns:dcns=\"http://purl.org/dc/elements/1.1/\" xmlns:dct=\"http://purl.org/dc/terms/\" xmlns:dcmit=\"http://purl.org/dc/dcmitype/\" xmlns:discovery=\"http://discovery-project.eu/ontologies/scholar/0.1/\" xmlns:swicky=\"http://discovery-project.eu/ontologies/philoSpace/\" xmlns:skos=\"http://www.w3.org/2004/02/skos/core#\" xmlns:marcont=\"http://www.marcont.org/ontology/2.1/\" xmlns:as_test_preds=\"http://testvalue.org/\" xmlns:meetest=\"http://www.meetest.org/me/\" xmlns:foafx=\"http://www.foafx.org/\">\n  <rdf:Description rdf:about=\"http://test.example.org/simple\">\n    <http://test.example.org/attribute3>\nAttribute Three    </http://test.example.org/attribute3>\n    <http://test.example.org/attribute4>\nAttribute Four    </http://test.example.org/attribute4>\n    <http://test.example.org/attribute5>\nAttribute Five    </http://test.example.org/attribute5>\n    <http://test.example.org/link>\n      <rdf:Description rdf:about=\"http://test.example.org/backlinked\"/>\n    </http://test.example.org/link>\n    <rdf:type>\n      <rdf:Description rdf:about=\"http://talia.discovery-project.eu/wiki/TaliaInternal#Source\"/>\n    </rdf:type>\n  </rdf:Description>\n</rdf:RDF>\n"
      assert_equal expected, @simple_source.to_lod_rdf(false)
    end

    def test_backlinks_lod_rdf
      expected = "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema#\" xmlns:rdfs=\"http://www.w3.org/2000/01/rdf-schema#\" xmlns:owl=\"http://www.w3.org/2002/07/owl#\" xmlns:local=\"http://localnode.org/\" xmlns:talia=\"http://talia.discovery-project.eu/wiki/TaliaInternal#\" xmlns:test=\"http://testnamespace.com/\" xmlns:foo=\"http://foo.com/\" xmlns:hyper=\"http://www.hypernietzsche.org/ontology/\" xmlns:dcns=\"http://purl.org/dc/elements/1.1/\" xmlns:dct=\"http://purl.org/dc/terms/\" xmlns:dcmit=\"http://purl.org/dc/dcmitype/\" xmlns:discovery=\"http://discovery-project.eu/ontologies/scholar/0.1/\" xmlns:swicky=\"http://discovery-project.eu/ontologies/philoSpace/\" xmlns:skos=\"http://www.w3.org/2004/02/skos/core#\" xmlns:marcont=\"http://www.marcont.org/ontology/2.1/\" xmlns:as_test_preds=\"http://testvalue.org/\" xmlns:meetest=\"http://www.meetest.org/me/\" xmlns:foafx=\"http://www.foafx.org/\">\n  <rdf:Description rdf:about=\"http://test.example.org/backlinked\">\n    <http://test.example.org/attribute1>\nAttribute One    </http://test.example.org/attribute1>\n    <http://test.example.org/attribute2>\nAttribute Two    </http://test.example.org/attribute2>\n    <rdf:type>\n      <rdf:Description rdf:about=\"http://talia.discovery-project.eu/wiki/TaliaInternal#Source\"/>\n    </rdf:type>\n  </rdf:Description>\n  <rdf:Description rdf:about=\"http://test.example.org/simple\">\n    <http://test.example.org/link>\n      <rdf:Description rdf:about=\"http://test.example.org/backlinked\"/>\n    </http://test.example.org/link>\n  </rdf:Description>\n</rdf:RDF>\n"
      assert_equal expected, @backlinked_source.to_lod_rdf(false)
    end

    def test_related_lod_rdf
      expected = "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema#\" xmlns:rdfs=\"http://www.w3.org/2000/01/rdf-schema#\" xmlns:owl=\"http://www.w3.org/2002/07/owl#\" xmlns:local=\"http://localnode.org/\" xmlns:talia=\"http://talia.discovery-project.eu/wiki/TaliaInternal#\" xmlns:test=\"http://testnamespace.com/\" xmlns:foo=\"http://foo.com/\" xmlns:hyper=\"http://www.hypernietzsche.org/ontology/\" xmlns:dcns=\"http://purl.org/dc/elements/1.1/\" xmlns:dct=\"http://purl.org/dc/terms/\" xmlns:dcmit=\"http://purl.org/dc/dcmitype/\" xmlns:discovery=\"http://discovery-project.eu/ontologies/scholar/0.1/\" xmlns:swicky=\"http://discovery-project.eu/ontologies/philoSpace/\" xmlns:skos=\"http://www.w3.org/2004/02/skos/core#\" xmlns:marcont=\"http://www.marcont.org/ontology/2.1/\" xmlns:as_test_preds=\"http://testvalue.org/\" xmlns:meetest=\"http://www.meetest.org/me/\" xmlns:foafx=\"http://www.foafx.org/\">\n  <rdf:Description rdf:about=\"http://test.example.org/resource1\">\n    <dcns:creator>\n      <rdf:Description rdf:about=\"http://test.example.org/creator1\"/>\n    </dcns:creator>\n    <dcns:publisher>\n      <rdf:Description rdf:about=\"http://test.example.org/publisher1\"/>\n    </dcns:publisher>\n    <http://test.example.org/name>\nRelated Source    </http://test.example.org/name>\n    <rdf:type>\n      <rdf:Description rdf:about=\"http://talia.discovery-project.eu/wiki/TaliaInternal#DcResource\"/>\n    </rdf:type>\n  </rdf:Description>\n  <rdf:Description rdf:about=\"http://test.example.org/creator1\">\n    <http://test.example.org/name>\nCreator One    </http://test.example.org/name>\n    <rdf:type>\n      <rdf:Description rdf:about=\"http://talia.discovery-project.eu/wiki/TaliaInternal#Source\"/>\n    </rdf:type>\n  </rdf:Description>\n  <rdf:Description rdf:about=\"http://test.example.org/publisher1\">\n    <http://test.example.org/name>\nPublisher One    </http://test.example.org/name>\n    <rdf:type>\n      <rdf:Description rdf:about=\"http://talia.discovery-project.eu/wiki/TaliaInternal#Source\"/>\n    </rdf:type>\n  </rdf:Description>\n</rdf:RDF>\n"
      assert_equal expected, @related_source.to_lod_rdf(false)
    end
  end
end
