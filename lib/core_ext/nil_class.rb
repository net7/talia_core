# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

class NilClass
  
  # See String#yes? from the core extensions. Always false here
  def yes? ; false ; end
  alias_method :true?, :yes?
  
  # See String#no? from the core extensions. Always true here
  def no? ; true ; end
  alias_method :false?, :no?
  
end