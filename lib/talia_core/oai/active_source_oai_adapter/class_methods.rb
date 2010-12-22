# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module Oai
    module OaiAdapterClassMethods

      # BY RIK 20101221
      # Using SourceOaiFields class for DC fields
      def namespaced_field(namespace, *fields)
        fields.each do |field|
          field = field.to_sym
          define_method(field) do            
            if namespace == :dcns
              return '' unless @record.class.oai_fields[field]
              @record[@record.class.oai_fields[field]] || ''
            else
              @record.predicate(namespace, field.to_s).values
            end
          end
        end
      end

    end
  end
end
