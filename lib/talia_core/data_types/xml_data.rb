# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require 'talia_core/data_types/file_store'
require 'rexml/document'
# require 'xml/xslt'

# Little helper to load the "tidy" library, to clean up
# messy XML/HTML, if possible. 
begin
  # if tidy is not present, disable it
  require 'tidy'
  
  # Tidy_enable constant is not defined?
  if ((defined? Tidy_enable) == nil)
    if ENV['TIDYLIB'].nil?
      # disable tidy
      Tidy_enable = false
    else
      # set path and enable tidy
      Tidy.path = ENV['TIDYLIB']
      Tidy_enable = true
    end
  end

rescue LoadError
  # disable tidy
  Tidy_enable = false if ((defined? Tidy_enable) == nil)
end
      

module TaliaCore
  module DataTypes
  
    # FileRecord class to store XML (or XHTML) files.
    class XmlData < FileRecord
      
      # MIME type should be one of 'text/html' or 'text/xml' 
      # ('text/hnml' is supported for legacy reasons)
      def extract_mime_type(location)
        # TODO: Could probably use the Mime classes to get the
        # type, or move to the superclass
        case File.extname(location).downcase
        when '.htm', '.html','.xhtml'
          'text/html'
        when '.hnml'
          'text/hnml'
        when '.xml'
          'text/xml'
        end
      end
      
      # The mime subtype for this specified class
      def mime_subtype
        mime_type.split(/\//)[1]
      end    

      # The content of this document. This returns REXML elements
      # for the document content. For plain XML files, this will
      # return the children of the doucment root. For XHTML documents,
      # this will return the children of the "body" tag.
      #
      # *Options*:
      # 
      # * [*xsl_file*] If given, the document will be transformed using this
      #                XSL file before the document is extracted
      def get_content(options = {})
        # TODO: Maybe port this to hpricot/nokogiri too
        text_to_parse = all_text
      
        # if xsl_file option is specified, execute transformation
        if (options[:xsl_file])
          text_to_parse = xslt_transform(file_path, options[:xsl_file])
        end

        # create document object
        document = REXML::Document.new text_to_parse
      
        # get content
        if ((mime_subtype == "html") or 
              ((mime_subtype == "xml") and (!options.nil?) and (!options[:xsl_file].nil?)))
          content = document.elements['//body'].elements
        elsif ((mime_subtype == "xml") or (mime_subtype == "hnml"))
          content = document.root.elements
        end
      
        # adjust/replace items path
        content.each { |i| wrapItem i }
      
        # return content
        return content
      end
    
      # Same as #get_content, but returns a string instead of the REXML documents
      def get_content_string(options = nil)
        xml_str = ''
        get_content(options).each do |element|
          xml_str << element.to_s
        end
        xml_str
      end
    
      # Same as #get_content_string, but with the XML escape for inclusion in 
      # HTML documents
      def get_escaped_content_string(options = nil)
        get_content_string(options).gsub(/</, "&lt;").gsub(/>/, "&gt;")
      end
    
      # See the FileStore module for details on how creation of data file objects works.
      # This version differs from the superclass version in that it will (optionally)
      # clean the HTML using the "tidy" tool. Also see http://tidy.rubyforge.org/
      #
      # Tidy will be used under the following circumstances:
      # 
      # * The "tidy" option is given and
      # * The library itself is available and
      # * The file appears to be a (X)HTML file
      #
      # *Options:*:
      #
      # [*tidy*] Use the "tidy" tool to clean up (X)HTML. Defaults to true if no options
      #          are given.
      def create_from_data(location, data, options = {:tidy => true})
        # check tidy option
        if (((options[:tidy] == true) and (Tidy_enable == true)) and 
              ((File.extname(location) == '.htm') or (File.extname(location) == '.html') or (File.extname(location) == '.xhtml')))        
        
          # apply tidy on data
          data_to_write = Tidy.open(:show_warnings => false) do |tidy|
            tidy.options.output_xhtml = true
            tidy.options.tidy_mark = false
            xhtml = tidy.clean(data)
            xhtml
          end
        else
          data_to_write = data
        end
      
        # write data
        super(location, data_to_write, options)
      end
    
      private
      
      # Helper that updates the paths in an XML element. Takes a REXML::Element, and updates
      # the paths for "img" and "a" tags to point to the Talia "source_data" controller.
      #
      # This is a quick hack to allow the rendering of HTML that contains those elements and 
      # needs to be fixed to show linked files that are stored in Talia.
      def wrapItem item
        # TODO: Quite hacky. Uses hardcoded paths, maybe should rather be a helper.
        if item.class == REXML::Element
          # recursive execution
          item.each_child { |subItem| wrapItem subItem}
    
          case item.name
          when "img"
            if item.attributes.include? "src"
              # get path
              path = Pathname.new(item.attributes['src']).split
              # adjust src attribute
              item.attributes['src'] = "/source_data/image_data/#{path[1].to_s}" if path[0].relative?
            end
          when "a"
            if item.attributes.include? "href"
              # get path
              path = Pathname.new(item.attributes['href']).split
              # adjust href attribute
              case File.extname(path[1].to_s)
              when ".txt"
                item.attributes['href'] = "/source_data/simple_text/#{path[1].to_s}" if path[0].relative?
              when '.htm', '.html','.xhtml','.hnml','.xml'
                item.attributes['href'] = "/source_data/xml_data/#{path[1].to_s}" if path[0].relative?
              end
            end
          end
       
        end
      end
    
      # Perform an XSLT transformation
      #
      # *Options*:
      #
      # [*document*] Xml document. Can be file path as string or REXML::Document
      # [*xsl_file*] Xsl file for transformation. Can be file path as string or REXML::Document
      def xslt_transform(document, xsl_file)
        xslt = XML::XSLT.new()
        # get xml document
        xslt.xml = document
        # get xslt document
        xslt.xsl = xsl_file

        # return transformation output
        return xslt.serve()      
      end
    
    end
  end
end