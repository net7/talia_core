module TaliaCore
  module ActiveSourceParts
    module Xml
      
      # Helper methods that can be used during the import operation
      module GenericReaderHelpers
        
        # Returns true if the given source was already imported. This can return false
        # if you call this for the currently importing source. 
        def source_exists?(uri)
          !@sources[uri].blank?
        end

        # Returns true if the currently imported element already contains type information
        # AND is of the given type.
        def current_is_a?(type)
          assit_kind_of(Class, type)
          @current.attributes['type'] && ("TaliaCore::#{@current.attributes['type']}".constantize <= type)
        end
        
        # Get the iso8601 string for the date
        def to_iso8601(date)
          return nil unless(date)
          date = DateTime.parse(date) unless(date.respond_to?(:strftime))
          date.strftime('%Y-%m-%dT%H:%M:%SZ')
        end
        
        # Parses the given string and returns it as a date object
        def parse_date(date, fmt = nil)
          return nil if(date.blank?)
          return DateTime.strptime(date, fmt) if(fmt) # format given
          return DateTime.new(date.to_i) if(date.size < 5) # this short should be a year
          DateTime.parse(date)
        end
        
        # Gets an absolute path to the given file url, using the base_file_url
        def get_absolute_file_url(url)
          orig_url = url.to_s.strip
          
          url = file_url(orig_url)
          # If a file:// was stripped from the url, this means it will always point
          # to a file
          force_file = (orig_url != url)
          # Indicates wether the base url is a network url or a file/directory
          base_is_net = !base_file_url.is_a?(String)
          # Try to find if we have a "net" URL if we aren't sure if this is a file. In
          # case the base url is a network url, we'll always assume that the
          # url is also a net thing. Otherwise we only have a net url if it contains a
          # '://' string
          is_net_url = !force_file && (base_is_net || url.include?('://'))
          # The url is absolute if there is a : character to be found
          
          
          if(is_net_url)
            base_is_net ? join_url(base_file_url, url) : url
          else
            base_is_net ? url : join_files(base_file_url, url)
          end
        end
        
        # Joins the two files. If the path is an absolute path,
        # the base_dir is ignored
        def join_files(base_dir, path)
          if(Pathname.new(path).relative?)
            File.join(base_dir, path)
          else
            path
          end
        end
        
        # Joins the two url parts. If the path is an absolute URL,
        # the base_url is ignored.
        def join_url(base_url, path)
          return path if(path.include?(':')) # Absolute URL contains ':'
          if(path[0..0] == '/')
            new_url = base_url.clone
            new_url.path = path
            new_url.to_s
          else
            (base_file_url + path).to_s
          end
        end
        
      end
      
    end
  end
end