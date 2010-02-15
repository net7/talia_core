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
    extend TaliaUtil::UriHelper
    
    attr_reader :user_url, :url
    
    def initialize(user_name, notebook_name)
      @user_url = self.class.user_url(user_name)
      @url = self.class.notebook_url(user_name, notebook_name)
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
      def find_all(user_name = nil)
        nb_query = ActiveRDF::Query.new(N::URI).select(:notebook).distinct
        nb_query.where(:notebook, N::RDF.type, N::TALIA.SwickyNotebook)
        nb_query.where(user_url(user_name), N::TALIA.hasSwickyNotebook, :notebook) if(user_name)
        nb_query.execute
      end
      
      def user_url(user_name)
        sanitize_sparql(N::LOCAL + "users/#{user_name}").to_uri
      end
      
      def notebook_url(user_name, notebook_name)
        sanitize_sparql(user_url(user_name) + '/swicky_notebooks/' + notebook_name).to_uri
      end
      
      def coordinates_for(url)
        url = sanitize_sparql(url).to_uri
        frag_qry = ActiveRDF::Query.new(N::URI).select(:coordinates).distinct
        frag_qry.where(:fragment, N::DISCOVERY.isPartOf, url)
        frag_qry.where(:fragment, N::SWICKY.hasCoordinates, :coordinates)
        frag_qry.where(:note, N::SWICKY.refersTo, :fragment)
        frag_qry.execute.collect { |coord| coord.to_s }
      end
      
      def annotations_for_url(url)
        url = sanitize_sparql(url).to_uri
        select_annotations([:note, N::SWICKY.refersTo, url])
      end
      
      def annotations_for_xpointer(xpointer)
        xpointer = sanitize_sparql(xpointer).to_uri
        select_annotations([:note, N::SWICKY.refersTo, :fragment], [:fragment, N::SWICKY.hasCoordinates, xpointer])
      end
      
      private
      
      def select_annotations(*note_matching)
        # Select all triples on the notes
        note_triples_qry = ActiveRDF::Query.new(N::URI).select(:note, :predicate, :object).distinct
        note_matching.each { |conditions| note_triples_qry.where(*conditions) }
        note_triples = note_triples_qry.where(:note, :predicate, :object).execute
        # Select all statements on the triples
        statement_triples_qry = ActiveRDF::Query.new(N::URI).select(:statement, :predicate, :object).distinct
        note_matching.each { |conditions| statement_triples_qry.where(*conditions) }
        statement_triples_qry.where(:note, N::SWICKY.hasStatement, :statement).where(:statement, :predicate, :object)
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