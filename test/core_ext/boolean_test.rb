# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require File.join(File.dirname(__FILE__), '..', 'test_helper')
require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'core_ext', 'boolean')

class BooleanTest < Test::Unit::TestCase
  
  def test_true_yes
    assert(true.yes?)
    assert(true.true?)
  end
  
  def test_true_no
    assert(!true.no?)
    assert(!true.false?)
  end
  
  def test_false_yes
    assert(!false.yes?)
    assert(!false.true?)
  end
  
  def test_false_no
    assert(false.no?)
    assert(false.false?)
  end
  
end