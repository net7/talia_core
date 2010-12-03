# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require 'guid'
module TaliaCore
  module ActiveSourceParts
    module Xml

      # A Reader for the "TaliaInternal" XML format. Check the code of this
      # class as a simple example of how an import reader works.
      #
      # An example of the import format can be found in the SourceBuilder 
      # documentation.
      class SourceReader < GenericReader

        # Match the XML tags called "source", creating a new source for
        # each of them
        element :source do
          # Match each "attribute" tag
          nested :attribute do
            # Read the predicate name(s) from "predicate" tag(s)
            predicate = from_element(:predicate)
            # We need to treat each value separately, as the can have 'xml:lang'
            # attributes, so we match each of the "value tags"
            nested :value do
              # Add the internationalized value from the current element, using
              # the "xml:lang" attribute for the language
              add_i18n predicate, from_element(:self), from_attribute('xml:lang')
            end
            # Match all the "object" tag and add their contents as relations
            add_rel predicate, all_elements(:object)
          end
          # Use the content of the "file" tag as a URI/filename for loading a data
          # file
          add_file all_elements(:file)
          @current.attributes["uri"] ||= Guid.new
        end

      end
      
    end
  end
end