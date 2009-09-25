require 'hpricot'

module TaliaCore
  module ActiveSourceParts
    module Xml

      # Base class for XML-based source-collection readers
      module ReaderBase

        module ClassMethods
          def sources_from_file(file)
            File.open(file) { |io| sources_from(io) }
          end

          def sources_from(source)
            reader = self.new(source)
            reader.sources
          end
        end 

        def initialize(source)
          @doc = Hpricot.XML(source)
        end
        
        def sources
          return @sources if(@sources)
          @sources = {}
          @doc.root.children.each do |element|
            next unless(element.is_a?(Hpricot::Elem))
            read_source(element)
          end
          @sources.values
        end
        
        def add_source_with_check(source_attribs)
          if((uri = source_attribs['uri']).blank?)
            TaliaCore.logger.warn("Problem reading from XML: Source without URI (#{source.attribs.inspect})")
          else
            @sources[uri] ||= {} 
            @sources[uri].each do |key, value|
              next unless(new_value = source_attribs.delete(key))
              
              assit(key.to_sym != :type, "Type should not change during import, may be a format problem")
              if(new_value.is_a?(Array) && value.is_a?(Array))
                # If both are Array-types, the new elements will be appended
                # and duplicates nwill be removed
                @sources[key] = (value + new_value).uniq
              else
                # Otherwise just replace
                @sources[key] = new_value
              end
            end
            # Now merge in everything else
            @sources[uri].merge!(source_attribs)
          end
        end
        
      end
    end

  end
end