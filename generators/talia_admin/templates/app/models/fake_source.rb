# Methods for "fake" source classes that let Hobo play (somewhat) 
# together with the classes from TaliaCore::*
module FakeSource  
  
  # Class methods for fake sources
  module ClassMethods
    
    def real_class
      @real_class ||= TaliaCore::Source
    end
    
    def has_real_class(klass)
      @real_class = klass
    end
    
    def find(*args)
      result = real_class.find(*args)
      if(result.is_a?(Array))
        result.collect { |s| from_real_source(s) }
      else
        result.nil? ? result : from_real_source(result)
      end
    end
    
    def count(*args)
      real_class.count(*args)
    end
    
    def new(*args)
      new_thing = super(*args)
      new_thing[:type] = real_class.name
      new_thing.real_source = real_class.new("http://#{rand Time.now.to_i}.x")
      new_thing.real_source.add_additional_rdf_types
      new_thing
    end

    def from_real_source(real_source)
      result = self.send(:instantiate, real_source.attributes)
      result.real_source = real_source
      result
    end
    
  end
  
  attr_writer :real_source
  
  def real_class
    self.class.real_class 
  end
  
  def name
    real_source.respond_to?(:label) ? real_source.label : to_uri.to_name_s
  end
  
  def short_type
    self.type ? self.type.gsub('TaliaCore::', '') : 'ActiveSource'
  end
  
  def to_uri
    self.uri.to_uri
  end

  def real_source
    @real_source ||= if(new_record?)
      real_class.new
    else
      TaliaCore::ActiveSource.find(self.id, :prefetch_relations => true)
    end
  end
  
  def rdf_mode
    nil
  end
  
  # Save the real source stuff, if it exists
  def save!
    save_real_source(true)
  end
  
  def save
    save_real_source(false)
  end
  
  def save_real_source(throws)
    real_source[:uri] = self[:uri]
    was_new = self.new_record?
    result = (throws ? real_source.save! : real_source.save)
    self.id = real_source.id
    self.instance_variable_set(:@new_record, false) if(was_new)
    result
  end
  
end
