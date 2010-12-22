module TaliaCore
  class SourceOaiFields < ActiveRecord::Base
    GUESSES = {
      :title => [N::DCNS.title, N::RDFS.label],
      :creator => [N::DCNS.creator],
      :subject => [N::DCNS.subject],
      :description => [N::DCNS.description, N::RDFS.description],
      :date => [N::DCNS.date],
      :type => [N::DCNS.type],
      :identifiers => [N::DCNS.type]
    }

  end
end
