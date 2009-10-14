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
