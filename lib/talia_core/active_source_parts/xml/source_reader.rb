module TaliaCore
  module ActiveSourceParts
    module Xml

      # Helper class to read an attribute hash from a Source XML
      class SourceReader < GenericReader

        element :source do
          nested :attribute do 
            add from_element(:predicate), all_elements(:value)
            add_rel from_element(:predicate), all_elements(:object)
          end
          add_file all_elements(:file)
        end

      end
      
    end
  end
end