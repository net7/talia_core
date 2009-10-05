module TaliaUtil
  
  # Mix-in for a class that wishes to use decoupled progress meters.
  module Progressable
    
    # This is the object that will receive the progress messages
    def progressor
      @progressor
    end
    
    # Set the progressor class. The progress class should simply respond to
    # a #run_with_progress(message, size, &block) class 
    def progressor=(progr)
      raise(ArgumentError, "Illegal progressor") unless((progr == nil) || progr.respond_to?(:run_with_progress))
      @progressor = progr
    end
    
    # Runs some block with a progress meter. The containing block will be
    # passed an object on which #inc can be called to increase the meter.
    # 
    # If no progressor object is passed in manually, the one configured
    # in the class is used
    def run_with_progress(message, size, progr = nil, &block)
      if(progr_object = (progr || progressor))
        progr_object.run_with_progress(message, size, &block)
      else
        dummy_prog = Object.new
        class << dummy_prog
          def inc
          end
        end
        block.call(dummy_prog)
      end
    end
    
  end
  
end