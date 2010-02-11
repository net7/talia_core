require 'builder'

module Swicky
  
  # Helper class to encode API result codes for the controller
  class ApiResult
    
    attr_accessor :result, :message
    RESULTS = {
      :success => 200,
      :illegal_parameter => 400,
      :error => 500
    }
    
    def initialize(result, message)
      raise(ArgumentError, "Illegal Result #{result}") unless(RESULTS.keys.include?(result.to_sym))
      @result = result.to_sym
      @message = message
    end
    
    def http_status
      RESULTS[result]
    end
    
    def to_xml
      xml = ''
      builder = Builder::XmlMarkup.new(:target => xml, :indent => 2)
      builder.instruct!
      builder.swicky_api do
        builder.result(result.to_s)
        builder.message(message)
      end
      xml
    end
    
    def to_json
      { :result => result, :message => message }.to_json
    end
    
    def to_html
      html = ''
      builder = Builder::XmlMarkup.new(:target => html, :indent => 2)
      builder.declare! :DOCTYPE, :html, :PUBLIC, "-//W3C//DTD XHTML 1.0 Strict//EN", "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"
      builder.html do
        builder.head { builder.title("Swicky request result") }
        builder.body do
          builder.h1("Result Code")
          builder.p(result.to_s)
          builder.h1("Message")
          builder.p(message)
        end
      end
      html
    end
    
  end
end