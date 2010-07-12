require File.join(File.dirname(__FILE__), '..', 'test_helper')
require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'core_ext', 'object')

class ObjectTest < Test::Unit::TestCase

  def test_try_call_on_existing
    assert_equal('abc', 'abc'.try_call.to_s)
  end
  
  def test_try_call_on_not_existing
    assert_nothing_raised do
      assert_equal(nil, 'abc'.try_call.foo)
    end
  end
  
  def test_try_call_on_existing_alternative
    assert_equal('abc', 'abc'.try_call(:to_s))
  end
  
  def test_try_call_on_not_existing_alternative
    assert_nothing_raised do
      assert_equal(nil, 'abc'.try_call(:foo))
    end
  end
  
end
