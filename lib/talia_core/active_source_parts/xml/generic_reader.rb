require 'hpricot'
require 'pathname'
require "set"
require "uri"

module TaliaCore
  module ActiveSourceParts
    module Xml

      # Superclass for importers/readers of generic xml files. The idea is that the
      # user can very easily create subclasses of this that can import almost any XML
      # format imaginable - see the SourceReader class for a simple example.
      #
      # The result of the "import" is a hash (available through #sources) which contains
      # all the data from the import file in a standardized format. This hash can then
      # be processed by the ActiveSource class to create the actual sources.
      #
      # = Writing XML importers
      #
      # Writing an importer is quite easy, all it takes is to subclass this class and
      # then describe the structure of the element using the methods defined here.
      #
      # The reader subclass should declare handlers for the various XML tags that are
      # in the file. See GenericReaderImportStatements for an explanation of how the
      # handlers work and how they are declared. This module also contains methods to
      # retrieve data from the XML in order to use it in the import
      #
      # The GenericReaderAddStatements contain the methods that are used to add data
      # to the source that is currently being imported.
      #
      # In addition to the SourceReader class that can be used as an example, the
      # other modules also contain some code examples for the mechanism.
      #
      # There are also some GenericReaderHelpers that can be used during the import.
      #
      # = Using an Importer
      #
      # The default way of using an importer is usually indirectly, through 
      # ActiveSource.create_from_xml. For direct use the sources_from_url or
      # sources_from methods can be called - these are the entry points for the
      # import process.
      #
      # = Result of the import operation
      #
      # The result of an import is an Array that contains a number of hashes. Each
      # of those can be passed to ActiveSource.new to create a new source object
      # with the given attributes.
      #
      # = Progress Reporting
      #
      # The class implements the TaliaUtil::Progressable interface, and if a
      # progressor object is assigned, it will report the progress to it during
      # the import operation.
      class GenericReader
        

        extend TaliaUtil::IoHelper
        include TaliaUtil::IoHelper
        include TaliaUtil::Progressable
        include TaliaUtil::UriHelper
        
        # Include all the parts
        include GenericReaderImportStatements
        extend GenericReaderImportStatements::Handlers
        include GenericReaderAddStatements
        include GenericReaderHelpers

        # Helper class for state
        class State
          attr_accessor :attributes, :element
        end

        class << self

          # See the IoHelper class for help on the options. A progressor may
          # be supplied on which the importer will report it's progress.
          def sources_from_url(url, options = nil, progressor = nil)
            open_generic(url, options) { |io| sources_from(io, progressor, url) }
          end

          # Read the sources from the given IO stream. You may specify a base
          # url to help the reader to decide from where files should be opened.
          def sources_from(source, progressor = nil, base_url=nil)
            reader = self.new(source)
            reader.base_file_url = base_url if(base_url)
            reader.progressor = progressor
            reader.sources
          end

          # Set the reader to allow the use of root elements for import
          def can_use_root
            @use_root = true
          end

          # True if the reader should also check the root element, instead of
          # only checking the children
          def use_root
            @use_root || false
          end

          # Returns the registered handlers
          attr_reader :create_handlers

          private

          # Adds an handler for the the given element. This will basically create an instance method 
          # <element_name>_handler, and add some bookkeeping information to the class.
          #
          # See call_handler to see how handlers are called.
          #
          # The creating parameter will indicate wether the handler, when called, will create a new
          # method or not.
          def element_handler(element_name, creating, &handler_block)
            element_name = "#{element_name}_handler".to_sym
            raise(ArgumentError, "Duplicate handler for #{element_name}") if(self.respond_to?(element_name))
            raise(ArgumentError, "Must pass block to handler for #{element_name}") unless(handler_block)
            @create_handlers ||= {}
            @create_handlers[element_name] = creating # Indicates whether a soure is created
            # Define the handler block method
            define_method(element_name, handler_block)
          end
        end # End class methods

        # Create a new reader. This parses the XML contained from the source and makes
        # the resulting XML document available to the reader
        def initialize(source)
          @doc = Hpricot.XML(source)
        end

        # Build a list of sources. This will return an array of hashes, and each 
        # hash can be used to create a new source with ActiveSource.new.
        #
        # The result will be cached and once read, subsequent calls will return
        # the same set of "sources" again
        def sources
          return @sources if(@sources)
          @sources = {}
          if(use_root && self.respond_to?("#{@doc.root.name}_handler".to_sym))
            run_with_progress('XmlRead', 1) { read_source(@doc.root) }
          else
            read_children_with_progress(@doc.root)
          end
          @sources.values
        end
        
        # This is the "base" for resolving file URLs. If a file URL is found
        # to be relative, it will be relative to this URL.
        #
        # If no base URL was specified this will use the file system path to
        # TALIA_ROOT
        def base_file_url
          @base_file_url ||= TALIA_ROOT
        end
        
        # Assign a new base_file_url
        def base_file_url=(new_base_url)
          @base_file_url = base_for(new_base_url)
        end

        # This will add the given source to the global result. source_attribs is a hash
        # with the attributes of one source. If that source already exists in the global
        # results, the two versions will be merged:
        #
        # * If the property is a list of values (an Array) in both the new and the old 
        #   version, these lists will be joined.
        # * Otherwise, the old property will be overwritten by the new one
        # 
        # The source_attribs *must* contain a URI, and they *must not* change a type
        # field that is anything else than nil or TaliaCore::SourceTypes::DummySource
        def add_source_with_check(source_attribs)
          assit_kind_of(Hash, source_attribs)
          # Check if we have a URI
          if((uri = source_attribs['uri']).blank?)
            raise(RuntimeError, "Problem reading from XML: Source without URI (#{source_attribs.inspect})")
          else
            source_attribs['uri'] = irify(uri) # "Irify" the URI (see UriHelper module)
            @sources[uri] ||= {} # This is the hash in the global result for our uri
            @sources[uri].each do |key, value| # Loop through existing results
              next unless(new_value = source_attribs.delete(key)) # Skip all existing that are not in the new attributes
              # Assert that we don't change a type away from DummySource - this would indicate some problem w/ the data
              assit(!((key.to_sym == :type) && (value != 'TaliaCore::SourceTypes::DummySource') && (value != new_value)), "Type should not change during import, may be a format problem. (From #{value} to #{new_value})")
              if(new_value.is_a?(Array) && value.is_a?(Array))
                # If both new and old are Array-types, the new elements will be appended
                # and duplicates will be removed
                @sources[uri][key] = (value + new_value).uniq
              else
                # Otherwise just replace the old value with the new one
                @sources[uri][key] = new_value
              end
            end
            # Everything that is only in the new attributes can be merged in
            @sources[uri].merge!(source_attribs)
          end
        end

        # Returns a hash with all handlers that "create" (that is, they
        # create a new source when called). This is taken from the class'
        # create_handlers accessor
        def create_handlers
          @handlers ||= (self.class.create_handlers || {})
        end

        # Read a single source from a XML elem. 
        # Pass in the XML element and an (optional)
        # block. This will call the handler (or block, see call_handler)
        # and add the result to the global result set using 
        # add_source_with_check
        def read_source(element, &block)
          attribs = call_handler(element, &block)
          add_source_with_check(attribs) if(attribs)
        end

        # As read_children of, using the standard progressor of the reader
        def read_children_with_progress(element, &block)
          run_with_progress('Xml Read', element.children.size) do |prog|
            read_children_of(element, prog, &block)
          end
        end

        # Read source data from each child of the given element
        # using read_source. Optionally reports the progress to
        # the given progressor.
        def read_children_of(element, progress = nil, &block)
          element.children.each do |element|
            progress.inc if(progress)
            next unless(element.is_a?(Hpricot::Elem)) # only use XML elements
            read_source(element, &block)
          end
        end

        # Same as use_root of the current class
        def use_root
          self.class.use_root
        end

        # Call the handler method for the given element. If a block is given, that
        # will be called instead. Pass in the XML element to read from.
        #
        # This saves the @current State object before calling the handler, and
        # restores it after the call is complete. Thus nested calls will have their
        # own state, but the state will be restored once you return to the 
        # parent handler.
        #
        # If a block is given, that block will be executed as the handler. Otherwise
        # the system checks for the "<element.name>_handler" method, and calls it. 
        # (See also element_handler)
        #
        # If no block is given and no handler is found, an error is logged.
        def call_handler(element)
          handler_name = "#{element.name}_handler".to_sym
          if(self.respond_to?(handler_name) || block_given?)
            parent_state = @current # Save the state for recursive calls
            attributes = nil
            begin
              creating = (create_handlers[handler_name] || block_given?)
              @current = State.new
              @current.attributes = creating ? {} : nil
              @current.element = element
              block_given? ? yield : self.send(handler_name)
              attributes = @current.attributes
            ensure
              @current = parent_state # Reset the state to previous value
            end
            attributes
          else
            TaliaCore.logger.warn("Unknown element in import: #{element.name}")
            false
          end
        end

        # Checks if the current status has an attribute hash, which means that there
        # is a "current" source being created at the moment.
        def chk_create
          raise(RuntimeError, "Illegal operation when not creating a source") unless(@current.attributes)
        end

        # Add a property to the source that is currently being imported. If no object is given, the method
        # just exits, unless required is set, in which case an error will be raised for an empty object.
        #
        # Database properties will be added as a single string, while other (semantic) properties will
        # always be added into an array (even if there is just a single object).
        #
        # This is the base code for adding elements, which is used for the add_* methods in 
        # GenericReaderAddStatements. This method should not usually be used directly.
        def set_element(predicate, object, required)
          chk_create
          object = check_objects(object)
          if(!object)
            raise(ArgumentError, "No object given, but is required for #{predicate}.") if(required)
            return
          end
          predicate = predicate.respond_to?(:uri) ? predicate.uri.to_s : predicate.to_s
          if(ActiveSource.db_attr?(predicate))
            assit(!object.is_a?(Array))
            @current.attributes[predicate] = object
          else
            @current.attributes[predicate] ||= []
            @current.attributes[predicate] << object
          end
        end

        # Pass in a list of elements that are to be used as objects in RDF triples.
        # This method will check the objects and remove any blank ones (which should
        # not be added). 
        #
        # If no non-blank element is found in the input, this will always return nil
        def check_objects(objects) 
          if(objects.kind_of?(Array))
            objects.reject! { |obj| obj.blank? }
            (objects.size == 0) ? nil : objects
          else
            objects.blank? ? nil : objects
          end
        end
        
      end

    end
  end
end
