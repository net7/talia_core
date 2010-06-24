# TaliaCore loader
require File.join(File.dirname(__FILE__), 'talia_dependencies')

require 'core_ext'
require 'talia_core/rdf_import'
require 'talia_util/rdf_update'
require 'progressbar'

# Stuff we just load from the gems
gem "builder"
require "builder"