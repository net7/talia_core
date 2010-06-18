require 'hpricot'
require 'pathname'

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
      # There are also some GenericReaderHelpers that can be used during the import
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

          # Reader the sources from the given IO stream. You may specify a base
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

          # Adds an handler for the the given element. The second parameter will
          # indicate if the handler will create a new source or not
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

        def initialize(source)
          @doc = Hpricot.XML(source)
        end

        # This builds
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
        # to be relative, it will be relative to this URL
        def base_file_url
          @base_file_url ||= TALIA_ROOT
        end
        
        # Assign a new base url
        def base_file_url=(new_base_url)
          @base_file_url = base_for(new_base_url)
        end

        def add_source_with_check(source_attribs)
          assit_kind_of(Hash, source_attribs)
          if((uri = source_attribs['uri']).blank?)
            raise(RuntimeError, "Problem reading from XML: Source without URI (#{source_attribs.inspect})")
          else
            uri = irify(uri)
            source_attribs['uri'] = uri
            @sources[uri] ||= {} 
            @sources[uri].each do |key, value|
              next unless(new_value = source_attribs.delete(key))

              assit(!((key.to_sym == :type) && (value != 'TaliaCore::SourceTypes::DummySource') && (value != new_value)), "Type should not change during import, may be a format problem. (From #{value} to #{new_value})")
              if(new_value.is_a?(Array) && value.is_a?(Array))
                # If both are Array-types, the new elements will be appended
                # and duplicates will be removed
                @sources[uri][key] = (value + new_value).uniq
              else
                # Otherwise just replace
                @sources[uri][key] = new_value
              end
            end
            # Now merge in everything else
            @sources[uri].merge!(source_attribs)
          end
        end

        def create_handlers
          @handlers ||= (self.class.create_handlers || {})
        end

        def read_source(element, &block)
          attribs = call_handler(element, &block)
          add_source_with_check(attribs) if(attribs)
        end

        def read_children_with_progress(element, &block)
          run_with_progress('Xml Read', element.children.size) do |prog|
            read_children_of(element, prog, &block)
          end
        end

        def read_children_of(element, progress = nil, &block)
          element.children.each do |element|
            progress.inc if(progress)
            next unless(element.is_a?(Hpricot::Elem))
            read_source(element, &block)
          end
        end

        def use_root
          self.class.use_root
        end

        private

        # Call the handler method for the given element. If a block is given, that
        # will be called instead
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

        def chk_create
          raise(RuntimeError, "Illegal operation when not creating a source") unless(@current.attributes)
        end

        # Add a property to the source currently being imported
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

        # Check the objects and sort out the blank ones (which should not be used).
        # If no usable object 
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