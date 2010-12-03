# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module TaliaUtil
  
  # Mix-in for a class that wishes to use decoupled progress meters. 
  # This creates an read/write accessor for a progressor, which is used
  # to report progress to.
  #
  # Inside the object #run_with_progress may be used to run a 
  # progress-reporting operation. If no progressor has been assigned,
  # run_with_progress will still work as expected, providing a progressor
  # object that will do nothing.
  #
  # = Example
  #
  #  class Foo
  #    
  #    include Progressable
  #
  #    def long_thing
  #      run_with_progress("doing long thing", 100) { |prog| (1..100).each { prog.inc } }
  #    end
  #  end
  #
  #  Foo.new.long_thing # Will do nothing
  #  foo_real = Foo.new
  #  foo_real.progressor = some_progressor
  #  foo_real.long_thing # reports progress to some_progressor
  #
  # = How a progressor must look like
  #
  # A progressor is simply required to provide a method called "run_with_progress(message, size)",
  # with the first parameter being the progress message and the second the overall 
  # count of operations. The method *must* take a block, and call that block with an object
  # which responds to a method calle "inc", which increases the current count/progress.
  #
  # = Example progressor
  #
  #  class DummyProgress
  #    def inc
  #      print '.'
  #    end
  #  end
  #
  #  class SimpleProgressor
  #    def self.run_with_progress(message, size)
  #      puts message
  #      yield(DummyProgress.new)
  #      puts "Done"
  #    end
  #  end
  #
  # This will print a dot for each thing that is processed. See also the BarProgressor for
  # another example
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