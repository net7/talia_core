# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

class User
  
  attr_accessor :roles
  
  def initialize
    @roles = ['reviewer','admin', 'editor'].sort!
  end
  
  def authorized_as?(role_name)
    if @roles.include?(role_name.to_s)
      return true
    else
      return false
    end
  end
  
end

class UserWithoutAuthorization
  
  attr_accessor :roles
  
  def initialize
    @roles = []
  end
  
  def authorized_as?(role_name)
    if @roles.include?(role_name.to_s)
      return true
    else
      return false
    end
  end
  
end
