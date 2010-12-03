# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module ActiveSourceParts
    module Xml
      
      # These are the statements that are use to add handler for elements or which are
      # used to otherwise read data for the element
      #
      # = What is an element handler?
      #
      # The methods in the Handlers submodule create element handlers. Handlers are the
      # starting point for the import operation and are the only statements at the top
      # level of the import description.
      #
      # Each handler will match a specific XML tag in the "current" XML content. At the 
      # beginning of the import the "current" content will be either the root element
      # or all of its child elements (depending on wether the can_use_root flag is set).
      #
      # The handlers will automatically attempt to match the element(s) at the starting
      # level:
      #
      #  class SampleReader < GenericReader
      #     
      #     can_use_root CAN_BE_TRUE_OR_FALSE
      #     
      #     element :foo do
      #       # Code for foo tags
      #     end
      #
      #     element :bar
      #       # Code for bar tags
      #     end
      #
      #     element :foobar
      #       # Code for foobar tags
      #     end
      #
      #  end
      # 
      # With this importer, there would be three handlers, for "foo", "bar" and
      # "foobar" tags. If you had the following XML
      #
      #  <foobar>
      #    <foo>Hello</foo>
      #    <bar>World</bar>
      #  </foobar>
      # 
      # When reader above is run on the sample XML, the follwoing will happen:
      #
      # * In case can_use_root has been set to true, the importer will start
      #   at the root element. In this case, the "Code for foobar tags" will
      #   be executed
      # * In case can_use_root has not been set, or set to false, the importer
      #   will work on the elements _inside_ the root tag. This means that
      #   it will first check the "foo" tag and call the "Code for foo tags"
      #   and then check the the "bar" tag and call the "Code for bar tags".
      #
      # Obviously an XML can also contain the same element multiple times, in
      # which case the handler will be called multiple time.
      #
      # = What happens inside a handler?
      #
      # When a handler is called, the "current" XML will be set to the inner
      # part of the current document. That is, in case of the "foobar" handler
      # the "current" XML would consist of the "foo" and "bar" tags (and their)
      # content. For the "foo" and "bar" handler, the "current" XML would be
      # just the text nodes inside it.
      #
      # The handler handler also has a "current" source that is being imported.
      # In case of a handler that was declared with .element, a new, empty
      # source is created whenever the handler is called. If the handler was
      # declared with .plain_element, the handler "inherits" the current source
      # that was active when it was called.
      #
      # Inside the handler, the GenericReaderAddStatements are used in order 
      # to add data and properties to the current source.
      #
      # All handlers are executed as instance methods of the current reader.
      #
      # = How are handlers called?
      #
      # The handlers that are declared in the importer are
      # matched against the "starting" tags in the XML and called 
      # automatically. Inside the handler methods like #add_source can be 
      # used to call a handler on sub-elements. Example for the
      # reader given above (with can_use_root set):
      #
      #  element :foobar do
      #    # At this point a new empty source has been created
      #    # and is set as the "current" source. The "current" XML
      #    # is the foo and bar tags
      #    add_source :foo # Takes the "foo" tag and calls the handler
      #    add_source :bar # Takes the "bar" tag and calls the handler
      #    # Alternatively: add_source :from_all_sources -> do both automatically
      #  end
      #
      # If the "foo" hanlder was defined as a .plain_element
      #
      #  plain_element :foo { }
      #
      # then the "foo" handler would inherit the source from the "foobar" handler
      # through wich it was called.
      #
      # = Accessing data within in the handlers
      #
      # While the handlers allow you to navigate through the XML structure, you
      # will also have to read the data in order to construct the sources.
      #
      # The from_* methods allow to read data from the current XML:
      #
      #  element :foobar do
      #    the_thing = from_element :foo
      #  end
      # 
      # In this case, inside the handler for the "foobar" tag, you attempt to
      # read the text from the :foo element. With the XML given above, the
      # result of this would be the string "Hello"
      module GenericReaderImportStatements
        
        # Methods to create handlers. See GenericReaderImportStatements
        module Handlers
          
          # Creates a handler for the element_name tag. Each time the handler
          # is called, a new, empty source is created and set as current.
          #
          # The handler block will be executed as an instance method on the
          # current reader object and the "current" XML inside the handler
          # block will be the inner XML of the "element_name" tag that is
          # currently being processed
          def element(element_name, &handler_block)
            element_handler(element_name, true, &handler_block)
          end

          # Works as #element, except that no new source is created. The 
          # current source in the block will be the one that is active
          # at the point where the handler was called.
          def plain_element(element_name, &handler_block)
            element_handler(element_name, false, &handler_block)
          end
          
        end # End handlers
        
        # Gets the data for an attribute of the current XML element. E.g. if
        # you have XML for
        #
        #  <foobar name="myself">
        #    <foo>Hello World</foo>
        #  </foobar>
        #
        # And this handler
        #
        #  element :foobar do
        #    my_attr = from_attribute :name
        #  end
        #
        # then the my_attr variable will be set to "myself"
        def from_attribute(attrib) 
          @current.element[attrib]
        end

        # Gets data from the XML tag "elem" inside the currently active XML
        # 
        # <foobar><foo>Hello World</foo></foobar>
        #
        # Inside the "foobar" handler `from_element :foo` would return
        # "Hello World" with the XML given above.
        def from_element(elem)
          return @current.element.inner_text.strip if(elem == :self)
          elements = all_elements(elem)
          elements = elements.uniq if(elements.size > 1) # Try to ignore dupes
          raise(ArgumentError, "More than one element of #{elem} in #{@current.element.inspect}") if(elements.size > 1)
          elements.first
        end
        
        # This works like #from_element, except that it will return an array with the
        # values of *all* "elem" tags inside the current XML.
        def all_elements(elem)
          result = []
          @current.element.search("/#{elem}").each { |el| result << el.inner_text.strip }
          result
        end
        
        # Adds a nested element. This will not change the currently importing source, but
        # it will set the currently active XML to the nested element. 
        # If a block is given, it will execute for each of the nested elements that
        # are found. Otherwise, a method name must be given, and that method will
        # be executed instead of the block
        def nested(sub_element, handler_method = nil)
          original_element = @current.element
          begin
            @current.element.search("#{sub_element}").each do |sub_elem|
              @current.element = sub_elem
              assit(block_given? ^ (handler_method.is_a?(Symbol)), 'Must have either a handler (x)or a block.')
              block_given? ? yield : self.send(handler_method)
            end
          ensure
            @current.element = original_element
          end
        end
        
        # Adds a source from the given sub-element. You may either pass a block with
        # the code to import or the name of an already registered element. If the
        # special value :from_all_sources is given, it will read from all sub-elements for which
        # there are registered handlers.
        #
        # If the method is used with a block, it will call the block as a handler for the _current_
        # element.l
        def add_source(sub_element = nil, &block)
          if(sub_element)
            if(sub_element == :from_all_sources)
              read_children_of(@current.element)
            else
              @current.element.search("/#{sub_element}").each { |sub_elem| read_source(sub_elem, &block) }
            end
          else
            raise(ArgumentError, "When adding elements on the fly, you must use a block") unless(block)
            attribs = call_handler(@current.element, &block)
            add_source_with_check(attribs) if(attribs)
          end
        end
        
        # Imports another source like add_source and also assigns the new source as
        # a part of the current one.
        def add_part(sub_element = nil, &block)
          raise(RuntimeError, "Cannot add child before having an uri to refer to.") unless(@current.attributes['uri'])
          @current.element.search("/#{sub_element}").each do |sub_elem|
            attribs = call_handler(sub_elem, &block)
            if(attribs)
              attribs[N::TALIA.part_of.to_s] ||= []
              attribs[N::TALIA.part_of.to_s] << "<#{@current.attributes['uri']}>"
              add_source_with_check(attribs)
            end
          end
        end
        
      end
      
    end
  end
end