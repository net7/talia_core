module TaliaCore
  
  # Some Excptions/Errors that are specific to the Talia system
  module Errors
    
    # Indicates an error during initialization
    class SystemInitializationError < RuntimeError
    end

    # Indicates an error with import data
    class ImportError < RuntimeError
    end
  
  end
end