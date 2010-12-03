# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require File.join(File.dirname(__FILE__), '..', 'test_helper')
require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'core_ext', 'nil_class')

class NilClassTest < Test::Unit::TestCase
  
  def test_yes
    assert(!nil.yes?)
  end
  
  def test_no
    assert(nil.no?)
  end
  
end
