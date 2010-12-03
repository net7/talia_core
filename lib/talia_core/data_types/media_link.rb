# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module DataTypes
    
    # Data class that contains just a link to a remote data element (and no
    # locally stored data at all). The uri for the link is stored in the location
    # field.
    #
    # *Note*: It is not possible to store data in media links, so all data-related
    # methods will raise an exception
    class MediaLink < DataRecord
      
      def all_bytes
        raise(RuntimeError, "Media Links have no data")
      end
      
      def get_byte(close_after_single_read=false)
        raise(RuntimeRror, "Media Links have no data")
      end
      
    end
  end
end
