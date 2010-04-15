module TaliaCore
  module SourceTypes

    # A generic SKOS concept. This means that this source represents an entry in
    # a taxonomy, thesaurus or the like.
    #
    # TODO: Stub class at the moment
    class SkosConcept < Source

      singular_property :pref_label, N::SKOS.prefLabel

    end

  end
end