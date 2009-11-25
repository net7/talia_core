module TaliaCore
  module ActiveSourceParts
    module Xml

      # Helper class to read an attribute hash from a Source XML
      class SourceReader < GenericReader

        element :source do
          nested :attribute do
            predicate = from_element(:predicate)
            # We need to treat each value separately, as the can have 'xml:lang'
            # attributes
            nested :value do
              add_i18n predicate, from_element(:self), from_attribute('xml:lang')
            end
            add_rel predicate, all_elements(:object)
          end
          add_file all_elements(:file)
        end

      end
      
    end
  end
end