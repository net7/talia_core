# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require 'rubygems'

# Some helpers for the Talia bootstrapping (when the module is loaded)
module TLoad

  # This tries to load the the given module. 
  # It first attempts to load from local_path/lib/local_name
  # The local path is always appended to the directory of the script
  # currently running.
  # If that fails, it tries to load the given gem
  def self.require_module(gem_name, local_name, local_path, gem_version = nil)
    begin
      # Try to loaTad from local if it exists
      search_dir = File.expand_path(File.join(File.dirname(__FILE__), local_path, "lib"))
      if(File.exists?(search_dir))
        $:.unshift(search_dir)  
        require local_name  
      else
        load_from_gem(gem_name, local_name, gem_version)
      end
    rescue LoadError
      load_from_gem(gem_name, local_name, gem_version)
    end
  end
  
  def self.start_dir
    @start_dir ||= begin
      # adding talia_core subdirectory to the ruby loadpath  
      file = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__
      this_dir = File.dirname(File.expand_path(file))
      $: << this_dir
      $: << this_dir + '/talia_core/'
      this_dir
    end
  end
   
  # Forces the loading of the parts of the rails framework that are used
  # by Talia
  def self.force_rails_parts
    require_module("activerecord", "active_record", "/../../../rails/activerecord", RAILS_GEM_VERSION) unless(defined?(ActiveRecord))
    require_module("activesupport", "active_support", "/../../../rails/activesupport", RAILS_GEM_VERSION) unless(defined?(ActiveSupport))
    require_module("actionpack", "action_controller", "/../../../rails/actionpack", RAILS_GEM_VERSION)
    # This sets the automatic loader path for Talia, allowing the ActiveSupport
    # classes to automatically load classes from this directory.
    # From 2.3.9(?) onward a new method autoload_path is "suggested" but 2.3.8 does not know it and gives error.
    # This is to avoid the error:
    begin
      load_paths = ActiveSupport::Dependencies.autoload_paths
    rescue NoMethodError
      load_paths = ActiveSupport::Dependencies.load_paths
    end      
    load_paths << TLoad.start_dir unless(load_paths.include?(TLoad.start_dir))
    # Add the other plugins to the path, if we have a Rails root
    if(defined?(RAILS_ROOT))
      Dir["#{RAILS_ROOT}/vendor/plugins/*/lib"].each do |plugin_dir|
        load_paths << plugin_dir if(File.directory?(plugin_dir) || !load_paths.include?(plugin_dir))
      end
    end
  end
  
  # Sets up the ActiveSupport autoload path
  def self.setup_load_path
    # set up the load path to talia
    root_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    Kernel.const_set(:TALIA_CODE_ROOT, root_dir) unless(defined?(TALIA_CODE_ROOT))
    lib_dir = File.join(root_dir, 'lib')
    # From 2.3.9(?) onward a new method autoload_path is "suggested" but 2.3.8 does not know it and gives error.
    # This is to avoid the error:
    begin
      load_paths = ActiveSupport::Dependencies.autoload_paths
    rescue NoMethodError
      load_paths = ActiveSupport::Dependencies.load_paths
    end      
    load_paths << lib_dir unless(load_paths.include?(lib_dir))
  end
  
  private
  
  def self.load_from_gem(gem_name, local_name, gem_version)
    if gem_version
      gem gem_name, gem_version
    else
      gem gem_name
    end
    
    require local_name
  end

end

TLoad.start_dir # Load the paths and start directory
