require 'rdf'
require 'rdf/ntriples'

module TaliaCore
  module ActiveSourceParts
    module Rdf

      class RdfReader

        extend TaliaUtil::IoHelper
        include TaliaUtil::IoHelper
        include TaliaUtil::Progressable

        class << self
          def sources_from_url(url, options=nil, progressor=nil)
            open_generic(url, options) {|io| sources_from(io, progressor, url)}
          end

          def sources_from(source, progressor=nil, base_url=nil)
            reader = self.new(source)
            reader.progressor = progressor
            reader.sources
          end

        end # End class methods

        def initialize(source)
          source = StringIO.new(source) if(source.is_a? String)
          @reader = RDF::Reader.for(:ntriples).new(source)
        end
        
        def sources
          return @sources if(@sources)
          @sources = {}
          @reader.each_statement do |statement|
            source = (@sources[statement.subject.to_s] ||= {})
            source['uri'] ||= statement.subject.to_s
            source['type'] ||= 'TaliaCore::Source'
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

      end
    end
  end
end
