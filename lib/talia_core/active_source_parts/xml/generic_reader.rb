module TaliaCore
  module ActiveSourceParts
    module Xml

      # Superclass for importers/readers of generic xml files. This is as close as possible
      # to the SourceReader class, and will (obviously) only work if a subclass fleshes out
      # the mappings.
      #
      # See the SourceReader class for a simple example.
      #
      # When adding new sources, the reader will always check if the element is already
      # present. If attributes for one source are imported in more than one place, all
      # subsequent calls will merge the newly imported attributes with the existing ones.
      class GenericReader

        include ReaderBase
        extend ReaderBase::ClassMethods

        # Helper class for state
        class State
          attr_accessor :attributes, :element
        end

        class << self

          # Create a handler for an element from which a source will be created
          def element(element_name, &handler_block)
            element_handler(element_name, true, &handler_block)
          end

          # Create a handler for an element which will be processed but from which
          # no source will be created
          def plain_element(element_name, &handler_block)
            element_handler(element_name, false, &handler_block)
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

        def create_handlers
          @handlers ||= (self.class.create_handlers || {})
        end

        def read_source(element)
          attribs = call_handler(element)
          add_source_with_check(attribs) if(attribs)
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

        # Adds a value for the given predicate (may also be a database field)
        def add(predicate, object, required = false)
          if(object.kind_of?(Array))
            object.each { |obj| set_element(predicate, obj.to_s, required) }
          else
            set_element(predicate, object.to_s, required)
          end
        end

        # Adds a relation for the given predicate
        def add_rel(predicate, object, required = false)
          if(object.kind_of?(Array))
            object.each do |obj| 
              raise(ArgumentError, "Cannot add relation on database field") if(ActiveSource.db_attr?(predicate))
              set_element(predicate, "<#{obj}>", required) 
            end
          else
            raise(ArgumentError, "Cannot add relation on database field") if(ActiveSource.db_attr?(predicate))
            set_element(predicate, "<#{object}>", required)
          end
        end

        # Returns true if the given source was already imported. This can return false
        # false if you call this for the currently importing source
        def source_exists?(uri)
          !@sources[uri].blank?
        end

        # Adds a source from the given sub-element. You may either pass a block with
        # the code to import or the name of an already registered element
        def add_source(sub_element = nil, &block)
          if(sub_element)
            (@current.element/sub_element).each do |sub_elem|
              attribs = call_handler(sub_elem, &block)
              add_source_with_check(attribs) if(attribs)
            end
          else
            raise(ArgumentError, "When adding elements on the fly, you must use a block") unless(block)
            attribs = call_handler(@current.element, &block)
            add_source_with_check(attribs) if(attribs)
          end
        end
        
        # Returns true if the currently imported element already contains type information
        # AND is of the given type.
        def current_is_a?(type)
          assit_kind_of(Class, type)
          @current.attributes[:type] && ("TaliaCore::#{@current.attributes[:type]}".constantize <= type)
        end
        
        # Adds a nested element. This will not change the currently importing source, but
        # it will set the currently active element to the nested element. 
        # A block must be given, it will execute for each of the nested elements that
        # are found
        def nested(sub_element)
          original_element = @current.element
          begin
            (@current.element/sub_element).each do |sub_elem|
              @current.element = sub_elem
              yield
            end
          ensure
            @current.element = original_element
          end
        end

        # Imports another source like add_source and also assigns the new source as
        # a part of the current one
        def add_part(sub_element = nil, &block)
          raise(RuntimeError, "Cannot add child before having an uri to refer to.") unless(@current.attributes['uri'])
          (@current.element/sub_element).each do |sub_elem|
            attribs = call_handler(sub_elem, &block)
            if(attribs)
              attribs[N::TALIA.part_of.to_s] ||= []
              attribs[N::TALIA.part_of.to_s] << "<#{@current.attributes['uri']}>"
              add_source_with_check(attribs)
            end
          end
        end

        # Add a property to the source currently being imported
        def set_element(predicate, object, required)
          chk_create
          if(required && (!object || (object.kind_of?(Array) && object.size == 0)))
            raise(ArgumentError, "No object given, but is required for #{predicate}.") 
          end
          predicate = predicate.respond_to?(:uri) ? predicate.uri.to_s : predicate.to_s
          if(ActiveSource.db_attr?(predicate))
            @current.attributes[predicate] = object
          else
            @current.attributes[predicate] ||= []
            @current.attributes[predicate] << object
          end
        end

        # Get an attribute from the current xml element
        def from_attribute(attrib)
          @current.element[attrib]
        end
        
        # Get the content of exactly one child element of type "elem" of the
        # currently importing element.
        def from_element(elem)
          elements = all_elements(elem)
          raise(ArgumentError, "Nore than one elements o #{elem}") unless(elements.size <= 1)
          elements.first
        end

        # Get the content of all child elements of type "elem" of the currently
        # importing element
        def all_elements(elem)
          result = []
          (@current.element/elem).each { |el| result << el.inner_html.strip }
          result
        end
      end

    end
  end
end