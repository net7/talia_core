# TaliaCore loader
require File.dirname(__FILE__) + '/loader_helper'

# This is also needed for local loading
RAILS_GEM_VERSION = '2.3.10' unless defined? RAILS_GEM_VERSION

# Stuff we may need to load from sources/uninstalled versions
TLoad::require_module("assit", "assit", "/../../assit") unless(defined?(assit))
TLoad::require_module("activerdf_net7", "active_rdf", "/../../ActiveRDF")
TLoad::require_module("semantic_naming", "semantic_naming", "/../../semantic_naming")

# Rails parts
TLoad::force_rails_parts unless(defined?(ActiveRecord))
TLoad::setup_load_path


require 'version'
