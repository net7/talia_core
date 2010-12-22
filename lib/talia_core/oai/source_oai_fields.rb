module TaliaCore
  module Oai
    class SourceOaiFields < ActiveRecord::Base

      def self.for(klass)
        configuration = {}
        configuration.merge! for_all.compact
        configuration.merge! for_klass(klass).compact

        configuration = configuration.to_options!
        [:updated_at, :created_at, :klass, :id].each do |field|
          configuration.delete(field)
        end

        configuration
      end

      def self.describe
        result = self.new.attributes.to_options!
        [:updated_at, :created_at, :klass, :id].each do |field|
          result.delete(field)
        end
        result.keys
      end

      def self.guess_fields
        @guess_fields ||= {
          :title       => [N::DCNS.title, N::RDFS.title],
          :description => [N::DCNS.description, N::RDFS.description],
          :creator     => [N::DCNS.creator],
          :subject     => [N::DCNS.subject],
          :date        => [N::DCNS.date],
          :type        => [N::DCNS.type],
          :identifier  => [N::DCNS.identifier]
        }
      end

      private

        def self.for_all
          result = find_by_klass('_all')
          result ? result.attributes : {}
        end

        def self.for_klass(klass)
          result = find_by_klass(klass) if klass != '_all'
          result ? result.attributes : {}
        end

      #end private
    end
  end
end
