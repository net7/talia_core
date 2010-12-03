# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module DataTypes
    
    # Base class for all data records that use a plain file for data storage. This 
    # implements the DataRecord API so that all byte methods work on a file in the 
    # File system. 
    #
    # Most of the operations are defined in the FileStore module, see there on how
    # to create and work with file records.
    #
    # See the DataLoader and MimeMapping modules to see new file records are 
    # created automatically, depending on the MIME type.
    #
    # The data paths are set automatically by the class, see PathHelpers
    #
    # There is also an IipLoader module, that contains the loader mechanism for
    # creating Iip images - you can also use that as an example to create
    # new loaders for other file types.
    class FileRecord < DataRecord
      include FileStore
      
      include PathHelpers
      extend PathHelpers::ClassMethods
      
      include DataLoader
      extend DataLoader::ClassMethods
      extend IipLoader
      extend TaliaUtil::IoHelper # Data IO for class methods
      
      after_save :write_file_after_save
      
      before_destroy :destroy_file
      
      # Returns and, if necessary, creates the file for "delayed" copy operations
      
      # Return all bytes from the file as a byte array.
      def all_bytes
        read_all_bytes
      end
      
      # Returns the next byte from the file (at the position of the
      # read cursor), or EOS if the end of the file has been reached.
      def get_byte(close_after_single_read=false)
        next_byte(close_after_single_read)
      end

      # Returns the current position of the read cursor
      def position
        return (@position != nil) ? @position : 0
      end
   
      # Reset the cursor to the beginning of the file
      def reset
        set_position(0)
      end
    
      # Set a new position for the read cursor
      def seek(new_position)
        set_position(new_position)
      end
    
      # Returns the file size in bytes
      def size
        data_size
      end
      
    end
    
  end
end
