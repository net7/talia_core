# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

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

