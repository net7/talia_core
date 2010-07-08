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
