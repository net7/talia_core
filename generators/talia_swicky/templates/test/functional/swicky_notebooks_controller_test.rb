require 'test_helper'

class SwickyNotebooksControllerTest < ActionController::TestCase
  
  def setup
    @notebook = Swicky::Notebook.new('dan', 'booky')
    @notebook_url = (N::LOCAL + 'users/dan/swicky_notebooks/bookyurl').to_s
    @testpointer = "http://dbin.org/swickynotes/demo/HanselAndGretel.htm#xpointer(start-point(string-range(//BODY/DIV[1]/TABLE[1]/TBODY[1]/TR[1]/TD[2]/P[46]/SPAN[1]/SPAN[1]/text()[1],'',7))/range-to(string-range(//BODY/DIV[1]/TABLE[1]/TBODY[1]/TR[1]/TD[2]/P[47]/SPAN[1]/text()[1],'',189)))"
  end
  
  def teardown
    @notebook.delete
  end
  
  def test_index_empty
    get(:index, :user_name => 'admin')
    assert_response(:success)
    assert_tag :ul, :children => { :count => 0 }
  end
  
  def test_index
    load_notebook
    get(:index, :user_name => 'admin')
    assert_response(:success)
    assert_select('ul') { assert_select 'li', @notebook_url }
  end
  
  def test_index_xml
    load_notebook
    get(:index, { :user_name => 'admin' }, :headers => { :accept => 'application/xml' })
    assert_select('notebooks') { assert_select 'notebook', @notebook_url }
  end
  
  def test_user_missing
    assert_raises(ActiveRecord::RecordNotFound) { get(:index, :user_name => 'foo') }
  end
  
  private
  
  def load_notebook
    @notebook.load(File.join(ActiveSupport::TestCase.fixture_path, "notebook.rdf"))
  end
  
end
