# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require 'yaml'

module TaliaCore #:nodoc:
  module Version #:nodoc:
    
    version = YAML.load_file(File.join(File.dirname(__FILE__), '..', 'VERSION.yml'))

    MAJOR = version[:major]
    MINOR = version[:minor]
    TINY  = version[:patch]

    STRING = [ MAJOR, MINOR, TINY ].join(".")

  end
end
