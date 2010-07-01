module TaliaCore
  module DataTypes
    
    # A FileRecord that contains an image.
    class ImageData < FileRecord
      
      # return the mime_type for a file
      def extract_mime_type(location)
        # TODO: This may work automatically if all the MIME types
        # are configured correctly (?)
        case File.extname(location).downcase
        when '.bmp'
          'image/bmp'
        when '.cgm'
          'image/cgm'
        when '.fit', '.fits'
          'image/fits'
        when '.g3'
          'image/g3fax'
        when '.gif'
          'image/gif'
        when '.jpg', '.jpeg', '.jpe'
          'image/jpeg'
        when '.png'
          'image/png'
        when '.tif', '.tiff'
          'image/tiff'
        end
      end
       
    end
    
  end
end