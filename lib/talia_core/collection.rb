module TaliaCore

  class Collection < DcResource

    has_rdf_type N::DCNS.Collection
    has_rdf_type N::SKOS.Collection
    has_rdf_type N::DCMIT.Collection

    simple_property :items, N::DCNS.hasPart

  end

end