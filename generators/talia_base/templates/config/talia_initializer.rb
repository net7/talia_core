# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

require 'talia_core'

TLoad::setup_load_path

TaliaCore::Initializer.environment = ENV['RAILS_ENV']
TaliaCore::Initializer.run("talia_core")

TaliaCore::SITE_NAME = TaliaCore::CONFIG['site_name'] || 'Talia Digital Library System'

# You may add mapping for additional data types here.
# TaliaCore::DataTypes::MimeMapping.add_mapping(:jpeg, TaliaCore::DataTypes::ImageData, :create_iip)