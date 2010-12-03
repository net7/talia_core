# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  
  # Represents a simple string value (literal property) of the RDF graph.
  # Each record will only contain the string value, which is stored in the
  # database as a text field.
  class SemanticProperty < ActiveRecord::Base
    
    validates_presence_of :value
    
  end
  
end
