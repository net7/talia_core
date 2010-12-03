# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

# TaliaCore loader
require File.join(File.dirname(__FILE__), 'talia_dependencies')

require 'core_ext'
require 'talia_core/rdf_import'
require 'talia_util/rdf_update'
require 'progressbar'

# Stuff we just load from the gems
gem "builder"
require "builder"