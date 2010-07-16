module TaliaCore
  
  # Represents a simple string value (literal property) of the RDF graph.
  # Each record will only contain the string value, which is stored in the
  # database as a text field.
  class SemanticProperty < ActiveRecord::Base
    
    validates_presence_of :value
    
  end
  
end
