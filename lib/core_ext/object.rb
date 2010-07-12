class Object


  class TryObject

    def initialize(original_object)
      @original_object = original_object
      
    end

    def method_missing(method, *args, &block)
      @original_object.send(method, *args, &block) if(@original_object.respond_to? method) 
    end
    
    # Hacky, Hacky, make all public private (we always want to call on @original_object)
    # new and alloc etc will automatically be ignored as they raise an exception
    public_instance_methods.each do |pub_method|
      begin ; private pub_method ; rescue NameError ; end
    end
    
  end

  
  # Tries to call the given method if it exists. If the method doesn't
  # exist, it will just return nil
  def try_call(*args, &block)
    if args.empty?
      TryObject.new(self)
    else
      self.send(*args, &block) if(self.respond_to?(args.first))
    end
  end
  
end