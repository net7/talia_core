module TaliaCore
  module Oai
    class SourceOaiFields < ActiveRecord::Base

      # Need the type colum to do other things
      set_inheritance_column :not_used

      def self.for(klass)
        configuration = {}
        configuration.merge! for_all.compact
        configuration.merge! for_klass(klass).compact

        [:updated_at, :created_at, :klass, :id].each do |field|
          configuration.delete(field)
        end

        configuration
      end

      def self.describe
        [:title, :description, :creator, :subject, :date, :type, :identifier]
      end

      def self.guess_fields
        @guess_fields ||= {
          :title       => [N::DCNS.title, N::RDFS.label, N::FOAF.name],
          :description => [N::DCNS.description, N::RDFS.description],
          :creator     => [N::DCNS.creator],
          :subject     => [N::DCNS.subject],
          :date        => [N::DCNS.date],
          :type        => [N::DCNS.type],
          :identifier  => [N::DCNS.identifier]
        }
      end

      def self.guess_default_fields
        guesses = {}
        oai_fields = self.guess_fields
        # Guessing works like this: for each oai field, for each candidate, 
        # count how many times the candidate is used as a predicate by any
        # source. The one with the higher count wins.
        # Ties are won by the earlier candidate in the list.
        oai_fields.each {|oai_field, candidates| guesses[oai_field] = self.guess_default_field candidates}
        guesses
      end

      def self.guess_default_field candidates
        return candidates.first.to_s if candidates.size == 1
        winner = nil
        winner_score = 0
        candidates.each do |candidate|
          sql  = "SELECT COUNT(B.predicate_uri) AS count "
          sql += "FROM active_sources A INNER JOIN semantic_relations B "
          sql += "ON A.id = B.subject_id "
          sql += "WHERE B.predicate_uri='#{candidate}';"

          score = self.find_by_sql(sql).first.attributes['count']

          if winner.nil? or score > winner_score
            winner = candidate.to_s
            winner_score = score
          end
        end
        winner
      end

      private

        def self.for_all
          result = find_by_klass('_all')
          result ? result.attributes.to_options : {}
        end

        def self.for_klass(klass)
          result = find_by_klass(klass) if klass != '_all'
          result ? result.attributes.to_options : {}
        end

      #end private
    end
  end
end
