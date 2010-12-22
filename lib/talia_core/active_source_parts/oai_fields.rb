module TaliaCore
  module ActiveSourceParts
    module OaiFields

      def oai?
        true
      end

      def has_oai_fields(fields={})
        @oai_fields = fields.merge load_oai_fields
      end

      def oai_fields
        @oai_fields || load_oai_fields
      end

      def guess_oai_fields
        guesses = {}
        oai_fields = TaliaCore::Oai::SourceOaiFields.guess_fields
        # Guessing works like this: for each oai field, for each candidate, 
        # count how many times the candidate is used as a predicate by sources 
        # of this class. The one with the higher count wins.
        # Ties are won by the earlier candidate in the list.
        oai_fields.each {|oai_field, candidates| guesses[oai_field] = guess_oai_field candidates}
        guesses
      end

      def guess_oai_field candidates
        return candidates.first.to_s if candidates.size == 1
        winner = nil
        winner_score = 0
        candidates.each do |candidate|
          sql  = "SELECT COUNT(B.predicate_uri) AS count "
          sql += "FROM active_sources A INNER JOIN semantic_relations B "
          sql += "ON A.id = B.subject_id "
          sql += "WHERE A.type='#{self.name}' and B.predicate_uri='#{candidate}';"

          score = self.find_by_sql(sql).first.attributes['count']

          if winner.nil? or score > winner_score
            winner = candidate.to_s
            winner_score = score
          end
        end
        winner
      end

      private
        def load_oai_fields
          TaliaCore::Oai::SourceOaiFields.for self.name
        end
      # end private
    end
  end
end
