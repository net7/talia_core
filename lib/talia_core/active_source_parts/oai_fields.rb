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

      private
        def load_oai_fields
          TaliaCore::Oai::SourceOaiFields.for self.name
        end
      # end private
    end
  end
end
