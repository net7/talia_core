# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaUtil
  
  # Some helper methods to deal with URI and IRI strings
  module UriHelper
    
    # Removes all characters that are illegal in IRIs, so that the
    # URIs can be imported
    def irify(uri)
      N::URI.new(uri.to_s.gsub( /[<>"{}|\\^`\s]/, '+')).to_s
    end
    
    # Sanitize an URI to be passed into SPARQL queries
    def sanitize_sparql(uri_or_string)
      uri_or_string = uri_or_string.to_s.gsub( /[<>"{}|\\^`\s]/, '') # Remove forbidden chars that we know of
      URI.escape(uri_or_string) # Escape everything else
      uri_or_string.gsub('%23', '#') # Revert the hash character, we need that intact
    end
    
  end
end