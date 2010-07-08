class NilClass
  
  # See String#yes? from the core extensions. Always false here
  def yes? ; false ; end
  alias_method :true?, :yes?
  
  # See String#no? from the core extensions. Always true here
  def no? ; true ; end
  alias_method :false?, :no?
  
end