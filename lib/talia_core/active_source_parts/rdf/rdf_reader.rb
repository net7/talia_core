require 'rdf'

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
        def initialize(source)
          TaliaUtil::Util.load_all_models
          source = StringIO.new(source) if(source.is_a? String)
          @reader = RDF::Reader.for(format).new(source)
        end
        
        # See TaliaCore::ActiveSourceParts::Xml::GenericReader#sources
        def sources
          return @sources if(@sources)
          @sources = {}
          run_with_progress('RdfRead', 0) do |progress|
            @reader.each_statement do |statement|
              source = (@sources[statement.subject.to_s] ||= {})
              source['uri'] ||= statement.subject.to_s
              update_source_type(source, statement)
              source[statement.predicate.to_s] ||= []
              object = if(statement.object.literal?)
                         parsed_string = PropertyString.parse(statement.object.value)
                         parsed_string.lang = statement.object.language.to_s if(statement.object.language)
                         parsed_string
                       else
                         "<#{statement.object.to_s}>"
                       end
              source[statement.predicate.to_s] << object
              progress.inc
            end
          end
          # Set all empty source types to ActiveSource, to prevent DummySource type objects to
          # be created. (Reason: When we import RDF, we assume that all sources are "valid", and should
          # never be marked as DummySource)
          @sources = @sources.values
          @sources.each { |s| s['type'] ||= 'TaliaCore::ActiveSource' }
          @sources
        end

        # Update the Talia source type. The type can be contained explicitly as object of a N::TALIA.type
        # predicate or can be inferred from the rdf type if a N::RDF.type predicate is present.
        #
        # The method works in the way that a N::TALIA type attribute always overwrites the type, while an
        # N::RDF.type will only be used if no type has been set on the source
        def update_source_type(source, statement)
          return if(statement.object.literal?)
          case(statement.predicate.to_s)
          when N::TALIA.type.to_s
            source['type'] = statement.object.to_s
          when N::RDF.type.to_s
            source['type'] ||= rdf_to_talia_type statement.object.to_s
          end
        end

        # Tries to gues at the talia type of a source given its rdf type.
        def rdf_to_talia_type(rdf_type)
          Class.subclasses_of(TaliaCore::ActiveSource).detect do |c|
            c.additional_rdf_types.include? rdf_type
          end.try :name
        end

        def format
          raise NotImplementedError
        end

      end
    end
  end
end
