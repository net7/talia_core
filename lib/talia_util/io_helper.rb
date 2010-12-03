# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require 'open-uri'

module TaliaUtil
  
  # Collection of IO methods than can be mixed into other classes
  module IoHelper

    # Generic "open" method for files and urls. This won't choke on file:// URLs and
    # will do some extra escaping on the URL. 
    #
    # *Usage*:
    #
    #  open_generic('someurl.foo') do |io|
    #    ...
    #  end
    #
    # See open_from_url for an explanation of the options
    def open_generic(url, options = {})
      url = file_url(url)
      # Even though open-uri would also open local files, we avoid to mangle
      # the URL in open_from_url
      if(File.exist?(url))
        File.open(url) { |io| yield(io) }
      else
        open_from_url(url, options) { |io| yield(io) }
      end
    end

    # Will try to figure out the "base", which is the parent directory or path.
    # If the base is a directory, this will return the directory name, but if
    # it is an URL, this will return an URI object.
    def base_for(url)
      url = file_url(url)
      if(File.exist?(url))
        file = File.expand_path(url)
        File.directory?(file) ? file : File.dirname(file)
      else
        uri = URI.parse(url)
        # Remove everything after the last '/'
        uri.path.gsub!(/\/[^\/]+\Z/, '/')
        uri.fragment = nil
        uri
      end
    end

    # Opens the given (web) URL, using URL encoding and necessary substitutions.
    # The user must pass a block which will receive the io object from
    # the url.
    #
    # The options may contain the http authentication information and such. See
    # the documentation for open-uri for more information. Example for options:
    # 
    #   :http_basic_authentication => [login, password]
    #
    # *Example*:
    #
    #  open_from_url('http://foobar.com/', :http_basic_authentication => ['user', 'secret']) do |io|
    #    ...
    #  end
    def open_from_url(url, options = {})
      # Encode the URI (the inner decode will save already-encoded URI and should
      # do nothing to non-encoded URIs)
      url = URI.encode(URI.decode(url))
      
      url.gsub!(/\[/, '%5B') # URI class doesn't like unescaped brackets
      url.gsub!(/\]/, '%5D')
      open_args = [ url ]
      open_args << options if(options)

      begin
        open(*open_args) do |io|
          yield(io)
        end
      rescue Exception => e
        raise(IOError, "Error loading #{url} (when file: #{url}, open_args: [#{open_args.join(', ')}]) #{e}")
      end
    end
    
    # Get the "file url" for the given uri, stripping a possible file:// from the front
    def file_url(uri)
      uri.gsub(/\Afile:\/\//, '')
    end
    
  end # End modules
end