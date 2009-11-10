module TaliaCore
  module SourceTypes

    # A generic resource that should contain the most important 
    # Dublin Core metadata fields
    class DcResource < Source

      # General metadata
      singular_property :identifier, N::DCNS.identifier
      simple_property :creators, N::DCNS.creator
      singular_property :date, N::DCNS.date
      singular_property :description, N::DCNS.description
      simple_property :publishers, N::DCNS.publisher
      singular_property :language, N::DCNS.language
      simple_property :dc_subjects, N::DCNS.subject
      singular_property :rights, N::DCNS.rights
      singular_property :title, N::DCNS.title

    end

  end
end