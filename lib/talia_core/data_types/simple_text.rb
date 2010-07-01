require 'talia_core/data_types/file_store'

# File Record that contains a plain text file.
module TaliaCore
  module DataTypes
  
    class SimpleText < FileRecord
      
      # The MIME type is always <tt>text/plain</tt>
      def extract_mime_type(location)
        'text/plain'
      end

      # Read onle line from the text file. The file will
      # be closed if the end of the file is hit, or
      # if close_after_single_read is set to true
      def get_line(close_after_single_read=false)
        if !is_file_open?
          open_file
        end
      
        # get a new line and return nil is EOF
        line = @file_handle.gets
      
        if line == nil or close_after_single_read
          close_file
        end
      
        # update the position of reading cursors
        @position += line.length
      
        return line
      end
      
    end
  end
end