require 'tempfile'

module Swicky
  
  # Represents a SWicky Notebook in the RDF store. This wraps the queries to handle 
  # the SWicky annotations and user notebooks.
  #
  # A notebook is an RDF subgraph that is store in its own context.
  #
  # All parameters for this class that end up in RDF queries will be sanitized 
  # automatically
  class Notebook
    
    include TaliaUtil::UriHelper
    include ActiveRDF::ResourceLike
    extend TaliaUtil::UriHelper
    
    attr_reader :user_url, :url
    
    alias :uri :url
    
    def initialize(user_name_or_uri, notebook_name = nil)
      if(notebook_name)
        @user_url = self.class.user_url(user_name_or_uri)
        @url = self.class.notebook_url(user_name_or_uri, notebook_name)
      else
        @url = sanitize_sparql(user_name_or_uri)
      end
    end
    
    def data
      @data ||= ActiveRDF::Query.new(N::URI).select(:s, :p, :o).distinct.where(:s, :p, :o, url).execute
    end
    
    def xml_data
      TaliaUtil::Xml::RdfBuilder.xml_string_for_triples(data)
    end
    
    def delete
      ActiveRDF::FederationManager.delete(nil, nil, nil, url)
      ActiveRDF::FederationManager.delete(user_url, N::TALIA.hasSwickyNotebook, url)
      ActiveRDF::FederationManager.delete(url, N::RDF.type, N::TALIA.SwickyNotebook)
    end
    
    def load(xml_file)
      @data = nil
      begin
        ActiveRDF::ConnectionPool.write_adapter.load(xml_file, 'rdfxml', url)
      rescue Exception => e
        puts "\tProblem loading #{xml_file.to_s}: (#{e.message}) File not loaded!"
        puts e.backtrace
      end
      ActiveRDF::FederationManager.add(user_url, N::TALIA.hasSwickyNotebook, url)
      ActiveRDF::FederationManager.add(url, N::RDF.type, N::TALIA.SwickyNotebook)
    end
    
    def create(xml_data)
      # Make a temp file for the data
      tmpfile = Tempfile.new('xml_notebook')
      tmpfile << xml_data
      tmpfile.close
      # Load into store
      load(tmpfile.path)
      # remove the temp file
      tmpfile.unlink
    end
    
    def exist?
      ActiveRDF::Query.new(N::URI).select(:user).where(:user, N::TALIA.hasSwickyNotebook, url).execute.size > 0
    end
    
    class << self
      
      # Find all notebooks for the given user
      def find_all(user_name = nil)
        nb_query = ActiveRDF::Query.new(Notebook).select(:notebook).distinct
        nb_query.where(:notebook, N::RDF.type, N::TALIA.SwickyNotebook)
        nb_query.where(user_url(user_name), N::TALIA.hasSwickyNotebook, :notebook) if(user_name)
        nb_query.execute
      end
      
      # Construct the "user" url for the given user name
      def user_url(user_name)
        sanitize_sparql(N::LOCAL + "users/#{user_name}").to_uri
      end
      
      # Construct the URL for a notebook from the user and notebook name
      def notebook_url(user_name, notebook_name)
        sanitize_sparql(user_url(user_name) + '/swicky_notebooks/' + notebook_name).to_uri
      end
      
      # Get the "coordinates" (an xpointer in the case of HTML fragments) for all the
      # fragments that are part of the element with the given url.
      def coordinates_for(url)
        url = sanitize_sparql(url).to_uri
        frag_qry = ActiveRDF::Query.new(N::URI).select(:coordinates).distinct
        frag_qry.where(:fragment, N::DISCOVERY.isPartOf, url)
        frag_qry.where(:fragment, N::SWICKY.hasCoordinates, :coordinates)
        frag_qry.where(:note, N::SWICKY.refersTo, :fragment)
        frag_qry.execute.collect { |coord| coord.to_s }
      end
      
      def annotation_list_for_url(url)
        qry = ActiveRDF::Query.new(N::URI).distinct.select(:note).where(:fragment, N::DISCOVERY.isPartOf, url.to_uri).where(:note, N::SWICKY.refersTo, :fragment).execute
      end
      
      # Select all the triples for all the annotations (notes) that refer to the given
      # URL
      def annotations_for_url(url)
        url = sanitize_sparql(url).to_uri
        select_annotations([:note, N::SWICKY.refersTo, url])
      end
      
      # Select all the annotations on the note that uses the fragment identified by the given XPOINTER
      # string
      def annotations_for_xpointer(xpointer)
        xpointer = sanitize_sparql(xpointer).to_uri
        select_annotations([:note, N::SWICKY.refersTo, :fragment], [:fragment, N::SWICKY.hasCoordinates, xpointer])
      end
      
      private
      
      # Select annotation triples. This expects an array of "where" conditions (that is, arrays with a 
      # subject-predicate-object pattern). One of the conditions must match a :note variable.
      # 
      # This will return all triples where:
      # 
      # * :note is the subject of the triple
      # * That have :statement as their subject, and :statement is a statement on one of the notes above
      # * That have any of the predicates or objects of the results above as their subject
      def select_annotations(*note_matching)
        # Select all triples on the notes
        note_triples_qry = ActiveRDF::Query.new(N::URI).select(:note, :predicate, :object).distinct
        note_matching.each { |conditions| note_triples_qry.where(*conditions) }
        note_triples = note_triples_qry.where(:note, :predicate, :object).execute
        # Select all statements on the triples
        statement_triples_qry = ActiveRDF::Query.new(N::URI).select(:subject, :predicate, :object).distinct
        note_matching.each { |conditions| statement_triples_qry.where(*conditions) }
        statement_triples_qry.where(:note, N::SWICKY.hasStatement, :statement)
        statement_triples_qry.where(:statement, N::RDF.subject, :subject)
        statement_triples_qry.where(:statement, N::RDF.predicate, :predicate)
        statement_triples_qry.where(:statement, N::RDF.object, :object)
        result_triples = note_triples + statement_triples_qry.execute
        # TODO: Fix this to better query once available in ActiveRDF
        additional_triples = []
        result_triples.each do |trip|
          additional_triples += ActiveRDF::Query.new(N::URI).select(:predicate, :object).distinct.where(trip[1].to_uri, :predicate, :object).execute.collect { |result| [trip[1].to_uri] + result }
          if(trip.last.respond_to?(:uri))
            additional_triples += ActiveRDF::Query.new(N::URI).select(:predicate, :object).distinct.where(trip.last, :predicate, :object).execute.collect { |result| [trip.last] + result }
          end
        end
        
        # Return all results
        result_triples + additional_triples
      end
      
    end
    
  end
end