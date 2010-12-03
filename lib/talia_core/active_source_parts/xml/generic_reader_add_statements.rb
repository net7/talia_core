# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module ActiveSourceParts
    module Xml
      
      # These are statements that can be used in handlers 
      # (see GenericReaderImportStatements to learn about handlers). They will
      # add data to the source that is currently being imported.
      module GenericReaderAddStatements
        
        # Adds a value for the given predicate (may also be a database field). Example:
        #
        #  add :uri, "http://foobar.org" # Set the uri of the current source to http://foobar.org
        #  add 'dct:creator', ['John Doe', 'Jane Doe'] # Sets the dct:creator property
        #
        # To add relations between source, see #add_rel
        def add(predicate, object, required = false)
          # We need to check if the object elements are already strings -
          # otherwise we would *.to_s the PropertyString objects, which would
          # destroy the metadata in them.
          if(object.kind_of?(Array))
            object.each { |obj| set_element(predicate, obj.is_a?(String) ? obj : obj.to_s, required) }
          else
            set_element(predicate, object.is_a?(String) ? object : object.to_s, required)
          end
        end
        
        # Works as #add, but also encodes the language (and potentially the type of the literal)
        # into the value.
        def add_i18n(predicate, object, lang, type=nil)
          object = object.blank? ? nil : TaliaCore::PropertyString.new(object, lang, type)
          add(predicate, object)
        end
        
        # Adds a date field. This will attempt to parse the original string
        # and write the result as an ISO 8061 compliant date string. Note
        # that this won't be able to parse everything you throw at it, though.
        def add_date(predicate, date, required = false, fmt = nil)
          add(predicate, to_iso8601(parse_date(date, fmt)), required)
        end
        
        # Adds a date interval as an ISO 8061 compliant date string. See
        # add_date for more info. If only one of the dates is given this
        # will add a normal date string instead of an interval.
        def add_date_interval(predicate, start_date, end_date, fmt = nil)
          return if(start_date.blank? && end_date.blank?)
          if(start_date.blank?)
            add_date(predicate, start_date, true, fmt)
          elsif(end_date.blank?)
            add_date(predicate, end_date, true, fmt)
          else
            add(predicate, "#{to_iso8601(parse_date(start_date, fmt))}/#{to_iso8601(parse_date(end_date, fmt))}", required)
          end
        end

        # Adds a relation for the given predicate. This works as #add,
        # but with the difference that it takes an object uri instead of 
        # a literal value. (See the #add method to add literal values):
        #
        #  add_rel 'dct:create', 'local:John', 'local:Jane'
        def add_rel(predicate, object, required = false)
          object = check_objects(object)
          if(!object)
            raise(ArgumentError, "Relation with empty object on #{predicate} (#{@current.attributes['uri']}).") if(required)
            return
          end
          if(object.kind_of?(Array))
            object.each do |obj| 
              raise(ArgumentError, "Cannot add relation on database field <#{predicate}> - <#{object.inspect}>") if(ActiveSource.db_attr?(predicate))
              set_element(predicate, "<#{irify(obj)}>", required) 
            end
          else
            raise(ArgumentError, "Cannot add relation on database field") if(ActiveSource.db_attr?(predicate))
            set_element(predicate, "<#{irify(object)}>", required)
          end
        end

        # Add a file to the source being imported. See the DataLoader module for a description of
        # the possible options.
        # 
        # Note that the import reader will not be able to resolve URLs or file names that are relative
        # to the original XML file or URL. File names should be absolute (otherwise they'll be treated
        # as relative to the current Talia working directory), as should be URLs. Furthermore,
        # the file names/paths must be valid on the machine _where the import takes place_.
        def add_file(urls, options = {})
          return if(urls.blank?)
          urls = [ urls ] unless(urls.is_a?(Array))
          files = urls.collect { |url| { :url => get_absolute_file_url(url), :options => options } }
          @current.attributes[:files] = files if(files.size > 0)
        end
        
        
        
      end
      
    end
  end
end