# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

class String
  # Transform the current string into a permalink.
  def to_permalink
    self.gsub(/\W+/, ' ').strip.downcase.titleize.gsub(/\ +/, '_')
  end
  
  # Give a URI object created from the current string
  def to_uri
    N::URI.new(self)
  end
  
  # Returns true if the string is "yes" or "true", regardless
  # of capitalization and leading/trailing spaces
  def yes?
    me = self.downcase.strip
    me == 'yes' || me == 'true'
  end
  alias_method :true?, :yes?
  
  # Like #yes?, just checking for "no" or "false"
  def no?
    me = self.downcase.strip
    me == 'no' || me == 'false'
  end
  alias_method :false?, :no?
  
end