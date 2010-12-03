# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

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