# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  
  # Contains all data types that are handled by the Talia system. All data elements
  # should be subclasses of DataRecord. Records that have data files attached are 
  # subclasses of FileRecord
  module DataTypes
   
    # Base class for all data records in Talia. This only contains a basic interface,
    # without much functionality. All data-related methods will return a 
    # NotImplementedError
    #
    # The DataRecord provides an interface to access a generic array/buffer of bytes,
    # with the base class not making any assumptions on how these bytes are stored.
    #
    # Subclasses should usually provide the inferface of this class, which is more
    # or less like the standard file interface.
    #
    # Each data record has a "location" field, which is roughly equivalent to the file
    # name, and a MIME type. The default behaviour is that, if not set manually,
    # the MIME type is automatically set before saving. It will be determined by
    # the "file extension" of the location field.
    #
    # Each data record must belong to an ActiveSource. For more information on how to 
    # handle records with files, see the FileRecord class
    class DataRecord < ActiveRecord::Base
      # Attention: These need to come before the extends, otherwise it'll blow the
      # tests
      belongs_to :source, :class_name => 'TaliaCore::ActiveSource'
      before_create :set_mime_type # Mime type must be saved before the record is written
      
      # validates_presence_of :source

      # Declaration of main abstract methods ======================
      # Some notes: every subclasses of DataRecord must implement
      #             at least the following methods
      # See also:   single-table inheritance    

      # returns all bytes in the object as an array of unsigned integers
      def all_bytes
        raise NotImplementedError
      end
    
      # Returns all_bytes as an binary string
      def content_string
        all_bytes.pack('C*') if(all_bytes)
      end

      # returns the next byte from the object, or nil at EOS  
      def get_byte(close_after_single_read=false)
        raise NotImplementedError
      end
    
      # returns the current position of the read cursor
      def position
        raise NotImplementedError
      end
    
      # adjust the position of the read cursor
      def seek(new_position)
        raise NotImplementedError
      end

      # returns the size of the object in bytes
      def size
        raise NotImplementedError
      end
    
      # reset the cursor to the initial state
      def reset
      end
      
      def extract_mime_type(location)
        # Lookup the mime type for the extension (removing the dot
        # in front of the file extension) Works only for the file
        # types supported by Rails' Mime class.
        Mime::Type.lookup_by_extension((File.extname(location).downcase)[1..-1]).to_s
      end
      
      def mime_type
        self.mime
      end
    
      attr_accessor :temp_path
      
      # class methods ============================================
      class << self

        # Find all data records about a specified source    
        def find_data_records(id)
          find(:all, :conditions => { :source_id => id })
        end

        def find_by_type_and_location!(source_data_type, location)
          # TODO: Should it directly instantiate the STI sub-class?
          # In this case we should use the following line instead.
          #
          # source_data = source_data_type.classify.constantize.find_by_location(location, :limit => 1)
          #
          data_type = "TaliaCore::DataTypes::#{source_data_type.camelize}"
          source_data = self.find(:first, :conditions => ["type = ? AND location = ?", data_type, location])
          
          raise ActiveRecord::RecordNotFound if source_data.nil?
          source_data
        end

      end

      private
      
    
      # Returns demodulized class name.
      def class_name
        self.class.name.demodulize
      end
    
      
      # set mime type if it hasn't been assigned already
      def set_mime_type
        assit(!self.location.blank?, "Location for #{self} should not be blank")
        if(!self.location.blank? && self.mime.blank?)
          # Set mime type for the record
          self.mime = extract_mime_type(self.location)
          assit_not_nil(self.mime, "Mime should not be nil (location was #{self.location})!")
        end
      end
      
    end
  end
end
