require 'rdf'
require 'rdf/ntriples'

module TaliaCore
  module ActiveSourceParts
    module Rdf

      # Import class for rdf ntriples files using rdf.rb (http://rdf.rubyforge.org/).
      # See GenericReader for more information on Talia import classes in general.
      class RdfReader

        extend TaliaUtil::IoHelper
        include TaliaUtil::IoHelper
        include TaliaUtil::Progressable

        class << self
          # See TaliaCore::ActiveSourceParts::Xml::GenericReader#sources_from_url
          def sources_from_url(url, options=nil, progressor=nil)
            open_generic(url, options) {|io| sources_from(io, progressor, url)}
          end

          # See TaliaCore::ActiveSourceParts::Xml::GenericReader#sources_from
          def sources_from(source, progressor=nil, base_url=nil)
            reader = self.new(source)
            reader.progressor = progressor
            reader.sources
          end

        end # End class methods

        # On inititalization: 
        # * We are going to use Class.subclasses_of method to determine the talia type of the source.
        #   Due to the autoload functionality of rails we need to be sure any possible source type class file 
        #   is loaded when we actually use that method. This is what TaliaUtil::Util::load_all_models does.
        # * Works only with format=:ntriples for now.
        def initialize(source, format=:ntriples)
          TaliaUtil::Util.load_all_models
          source = StringIO.new(source) if(source.is_a? String)
          @reader = RDF::Reader.for(format).new(source)
        end

        
        # See TaliaCore::ActiveSourceParts::Xml::GenericReader#sources
        def sources
          return @sources if(@sources)
          @sources = {}
          @reader.each_statement do |statement|
            source = (@sources[statement.subject.to_s] ||= {})
            source['uri'] ||= statement.subject.to_s
            source['type'] ||= find_source_type statement
            source[statement.predicate.to_s] ||= []
            object = if(statement.object.literal?)
              PropertyString.parse(statement.object.value)
            else
              "<#{statement.object.to_s}>"
            end
            source[statement.predicate.to_s] << object
          end
           @sources.values
        end

        # Used to determine the source talia type. The type can be contained explicitly as object of a N::TALIA.type
        # predicate or can be inferred from the rdf type if a N::RDF.type predicate is present.
        def find_source_type(statement)
          return nil if(statement.object.literal?)
          if(statement.predicate.to_s == N::TALIA.type.to_s)
            statement.object.to_s
          elsif(statement.predicate.to_s == N::RDF.type.to_s)
            rdf_to_talia_type statement.object.to_s            
          else
            nil
          end
        end

        # Tries to gues at the talia type of a source given its rdf type.
        def rdf_to_talia_type(rdf_type)
          Class.subclasses_of(TaliaCore::ActiveSource).detect do |c|
            c.additional_rdf_types.include? rdf_type
          end.try :name
        end

      end
    end
  end
end
