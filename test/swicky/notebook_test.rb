require File.join(File.dirname(__FILE__), '..', 'test_helper')
require 'rexml/document'

module Swicky
  
  # Test the ActiveSource
  class NotebookTest < ActiveSupport::TestCase
    
    
    def setup
      @notebook = Notebook.new('dan', 'booky')
      @testpointer = "http://dbin.org/swickynotes/demo/HanselAndGretel.htm#xpointer(start-point(string-range(//DIV[@id='http://dbin.org/swickynotes/demo/HG_1']/P[1]/SPAN[1]/text()[1],'',0))/range-to(string-range(//DIV[@id='http://dbin.org/swickynotes/demo/HG_1']/P[1]/SPAN[1]/text()[1],'',266)))"
    end
    
    def teardown
      @notebook.delete
    end
    
    def test_url
      assert_equal(@notebook.url, N::LOCAL + 'users/dan/swicky_notebooks/booky')
    end
    
    def test_user_url
      assert_equal(@notebook.user_url, N::LOCAL + 'users/dan')
    end
    
    def test_load
      assert_notebook_empty
      load_notebook
      assert_notebook_full
    end
    
    def test_delete
      load_notebook
      @notebook.delete
      assert_notebook_empty
    end
    
    def test_data
      load_notebook
      assert_equal(@notebook.data.size, 236)
    end
    
    def test_xml_data
      load_notebook
      xml_data = @notebook.xml_data
      assert_kind_of(String, xml_data)
      assert_not_equal('', xml_data)
      # Check xml validity
      assert_nothing_raised { REXML::Document.new(xml_data) }
    end
    
    def test_find_all_empty
      assert_equal([], Notebook.find_all)
    end
      
    def test_find_all_existing
      load_notebook
      assert_equal([@notebook.url], Notebook.find_all)
    end
      
    def test_find_all_user
      load_notebook
      assert_equal([@notebook.url], Notebook.find_all('dan'))
    end
    
    def test_find_all_user_nonexistent
      load_notebook
      assert_equal([], Notebook.find_all('mic'))
    end
    
    def test_get_coordinates
      load_notebook
      coords = Notebook.coordinates_for("http://dbin.org/swickynotes/demo/HanselAndGretel.htm")
      assert_equal([ @testpointer ], coords)
    end
    
    def test_annotations_for_url
      load_notebook
      assert_equal(293, Notebook.annotations_for_url("http://discovery-project.eu/ontologies/philoSpace/SourceFragment#ec9796a5349b290a7610763dcbc47af2").size)
    end
    
    def test_annotations_for_xpointer
      load_notebook
      assert_equal(293, Notebook.annotations_for_xpointer(@testpointer).size)
    end
    
    private
    
    def assert_notebook_empty
      assert_equal(0, Query.new(N::URI).select(:s, :p, :o).distinct.where(:s, :p, :o, @notebook.url).execute.size)
      assert_equal(0, Query.new(N::URI).select(:user).where(:user, N::TALIA.hasSwickyNotebook, :notebook).where(:notebook, N::RDF.type, N::TALIA.SwickyNotebook).execute.size)
    end
    
    def assert_notebook_full
      assert_equal(236, Query.new(N::URI).select(:s, :p, :o).distinct.where(:s, :p, :o, @notebook.url).execute.size)
      assert_equal(1, Query.new(N::URI).select(:user).where(:user, N::TALIA.hasSwickyNotebook, :notebook).where(:notebook, N::RDF.type, N::TALIA.SwickyNotebook).execute.size)
    end
    
    def load_notebook
      @notebook.load(TaliaCore::TestHelper.fixture_file("notebook.rdf"))
    end
    
  end
  
end