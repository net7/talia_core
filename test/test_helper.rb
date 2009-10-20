$: << File.join(File.expand_path(File.dirname(__FILE__)), '..', 'lib')
require 'fileutils'
require 'test/unit'
require 'core_ext'
require "talia_core"
require "talia_util/test_helpers"
require 'active_support/test_case'
require 'active_record/fixtures'

class ActiveSupport::TestCase
  include ActiveRecord::TestFixtures
  self.fixture_path=File.join(File.dirname(__FILE__), 'fixtures')
  self.use_instantiated_fixtures  = false
  self.use_transactional_fixtures = true
end


module TaliaCore
  #  class Source
  #    public :instantiate_source_or_rdf_object
  #  end
  
  class TestHelper
    # Check if we have old (1.2.3-Rails) style ActiveRecord without fixture cache
    @@new_ar = Fixtures.respond_to?(:reset_cache)
    
    # connect the database
    def self.startup
      if(!TaliaCore::Initializer.initialized)
        TaliaCore::Initializer.talia_root = File.join(File.dirname(__FILE__))
        TaliaCore::Initializer.environment = "test"
        # run the initializer
        TaliaCore::Initializer.run("talia_core")
        true
      else
        false
      end
    end
    
    def self.create_data_dir
      ddir = TaliaCore::CONFIG['data_directory_location']
      raise(RuntimeError, "No data directory configured") unless(ddir)
      
      if(File.exist?(ddir))
        raise(RuntimeError, "Data dir not a directory") unless(File.directory?(ddir))
        if(File.exist?(File.join(ddir, 'README_FOR_TEST')))
          puts "*** REMOVING data directory at #{ddir} - this should be used for testing only!"
          FileUtils.rm_rf(ddir)
        else
          puts "*** WARNING: The #{ddir} directory does not seem to be an automatic test directory."
          puts "             Maybe something is wrong with your test/config/talia.yml ?"
        end
      end
      unless(File.exist?(ddir))
        fixture_dir = File.join(ActiveSupport::TestCase.fixture_path, 'data_for_test')
        puts "Copying fixture data to data directory #{ddir} -> #{fixture_dir}"
        FileUtils.cp_r(fixture_dir, ddir)
      end
    end
    
    def self.fixture_file(filename)
      File.join(ActiveSupport::TestCase.fixture_path, filename)
    end
    
    def self.flush_store
      TaliaUtil::Util.flush_rdf
      TaliaUtil::Util.flush_db
      Fixtures.reset_cache if(@@new_ar)
      true
    end
  end
  
  ActiveRecord::Base.store_full_sti_class = true
  started = TestHelper.startup
  ActiveSupport::TestCase.set_fixture_class :active_sources => TaliaCore::ActiveSource,
    :semantic_properties => TaliaCore::SemanticProperty,
    :semantic_relations => TaliaCore::SemanticRelation,
    :sources => TaliaCore::Source,
    :data_records => TaliaCore::DataTypes::DataRecord
  TestHelper.create_data_dir if(started)

end
