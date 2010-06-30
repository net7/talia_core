module TaliaCore
  module ActiveSourceParts
    module Rdf
      class RdfxmlReader < RdfReader
        require 'rdf/raptor'
        def format
          :rdfxml
        end
      end
    end
  end
end
