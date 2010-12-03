# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module Oai
    
    module OaiAdapterClassMethods
      
      def namespaced_field(namespace, *fields)
        fields.each do |field|
          define_method(field.to_sym) do
            @record.predicate(namespace, field.to_s).values
          end
        end
      end
      
    end
    
  end
end