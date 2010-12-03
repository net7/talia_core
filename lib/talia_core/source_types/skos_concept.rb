# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module SourceTypes

    # A generic SKOS concept. This means that this source represents an entry in
    # a taxonomy, thesaurus or the like.
    #
    # TODO: Stub class at the moment
    class SkosConcept < Source
      
      N::SKOS.Concept

      singular_property :pref_label, N::SKOS.prefLabel

    end

  end
end