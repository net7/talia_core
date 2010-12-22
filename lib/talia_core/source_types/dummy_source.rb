# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaCore
  module SourceTypes

    # Dummy source class. This will be created by some mechanisms that need to create a relation to a 
    # not-yet-existing source. The DummySource should only exist temporarily, if some are found inside
    # the data store it may be a sign of an inconsistent or not completely initialized store.
    class DummySource < Source

      def self.oai?
        false
      end

      # Converts the current source into one with a "real" klass. Returns the new, converted sourc
      def self.make_real(klass)
        assit_kind_of(Class, klass)
        self['type'] = klass.name
        save!
        new_src = ActiveSource.find(uri)
        assit_kind_of(klass, new_src)
        new_src
      end

    end

  end
end
