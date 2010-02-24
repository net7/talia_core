class SwickyNotebooksController < ApplicationController
  
  before_filter :get_user, :except => [:annotated_fragments, :annotations]
  before_filter :basic_auth
  before_filter :get_notebook, :except => [:index, :create, :annotated_fragments, :annotations]
  skip_before_filter :verify_authenticity_token

  rescue_from NativeException, :with => :rescue_native_error
  rescue_from(URI::InvalidURIError) { render_api_result(:illegal_parameter, "Illegal URI?") }
  
  # GET 
  def index
    @notebooks = Swicky::Notebook.find_all
  end

  # GET 
  def show
    raise(ActiveRecord::RecordNotFound, "Notebook doesn't exist #{@notebook.url}") unless(@notebook.exist?)
    respond_to do |format|
      format.xml { render :text => @notebook.xml_data }
      format.rdf { render :text => @notebook.xml_data }
      format.html { render }
    end
  end

  # POST
  def create
    @notebook = Swicky::Notebook.new(@user.name, params[:notebook_name])
    @notebook.delete
    @notebook.load(params[:contentfile].path)
    respond_to do |format|
      format.xml { render :text => @notebook.xml_data }
      format.rdf { render :text => @notebook.xml_data }
      format.html { render }
    end
  end
  
  # PUT
  def update
    @notebook.delete
    @notebook.load(params[:contentfile].path)
    render_api_result(:success, "Notebook updated")
  end
  
  # DELETE
  def destroy
    raise(ActiveRecord::RecordNotFound, "Notebook doesn't exist #{@notebook.url}") unless(@notebook.exist?)
    @notebook.delete
    render_api_result(:success, "Notebook deleted")
  end
  
  def annotated_fragments
    coordinates = Swicky::Notebook.coordinates_for(URI.escape(params[:uri]).to_s)
    render :text => coordinates.to_json
  end
  
  def annotations
    notes_triples = if(params[:uri])
      Swicky::Notebook.annotations_for_url(params[:uri])
    elsif(params[:xpointer])
      Swicky::Notebook.annotations_for_xpointer(params[:xpointer])
    else
      raise(ActiveRecord::RecordNotFound, "No parameter given for annotations")
    end
    respond_to do |format|
      format.xml { render :text => Swicky::ExhibitJson::ItemCollection.new(notes_triples, params[:xpointer] || params[:uri]).to_json }
      format.rdf { render :text => TaliaUtil::Xml::RdfBuilder.xml_string_for_triples(notes_triples) }
      format.html { render :text => Swicky::ExhibitJson::ItemCollection.new(notes_triples, params[:xpointer] || params[:uri]).to_json }
      format.json { render :text => Swicky::ExhibitJson::ItemCollection.new(notes_triples, params[:xpointer] || params[:uri]).to_json }
    end
  end
  
  private
  
  def rescue_native_error(exception)
    if(exception.cause.class.name =~ /\AJava::OrgOpenrdfQuery/)
      render_api_result(:illegal_parameter, "Query Error. Wrong URI?")
    else
      raise exception
    end
  end
  
  def render_api_result(result, message)
    result = Swicky::ApiResult.new(result, message)
    respond_to do |format|
      format.xml { render :text => result.to_xml, :status => result.http_status }
      format.rdf { render :text => result.to_xml, :status => result.http_status }
      format.html { render :text => result.to_html, :status => result.http_status }
      format.json { render :text => result.to_json, :status => result.http_status }
    end
  end
  
  def get_user
    @user = User.find_by_name(params[:user_name])
    raise(ActiveRecord::RecordNotFound, "No user #{params[:user_name]}") unless(@user)
  end
  
  def get_notebook
    @notebook = Swicky::Notebook.new(@user.name, params[:id])
  end
  
  def basic_auth
    return true if(request.get?)
    user_email = @user.email_address
    authenticate_or_request_with_http_basic("Swicky") do |user, pass|
      @auth_user = User.authenticate(user_email, pass) if(@user.name == user)
    end
  end
  
  
end
