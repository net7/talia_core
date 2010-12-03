# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module Platform # :nodoc:
  extend self

  def jruby?
    RUBY_PLATFORM =~ /java/
  end
  
end

extend Platform
