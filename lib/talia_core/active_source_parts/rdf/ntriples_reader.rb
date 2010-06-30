module TaliaCore
  module ActiveSourceParts
    module Rdf
      class NtriplesReader < RdfReader
        require 'rdf/ntriples'
        def format
          :ntriples
        end
      end
    end
  end
end

