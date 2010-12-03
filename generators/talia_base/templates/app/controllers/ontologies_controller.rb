# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

class OntologiesController < ApplicationController
  
    def index
      onto_qry =  ActiveRDF::Query.new(N::URI).select(:context).distinct.where(N::TALIA.rdf_context_space, N::TALIA.rdf_file_context, :context)
      @ontologies = onto_qry.execute.collect { |context| context.local_name }
    end
    
    def show
      ontology_url = N::TALIA + URI.encode(params[:id])
      @triples = ActiveRDF::Query.new(N::URI).select(:s, :p, :o).where(:s, :p, :o, ontology_url).execute
    end
    
end
