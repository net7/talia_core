module TaliaCore
  module SourceTypes

    # A generic SKOS concept. This means that this source represents an entry in
    # a taxonomy, thesaurus or the like.
    #
    # TODO: Stub class at the moment
    class MarcontResource < Source
      
      has_rdf_type N::MARCONT.Resource

    end

  end
end