begin
  require 'oai'
rescue LoadError
  puts "ERROR: You have enabled the Talia OAI interface, but the OAI library was not found."
  puts "Please do 'gem install oai_talia' to fix this. (Gem is hosted on gemcutter.org)"
  puts 
  raise
end

class TaliaOaiProvider < OAI::Provider::Base
  repository_name 'Talia OAI Interface'
  repository_url N::LOCAL.oai.to_s
  record_prefix 'oai:talia'
  admin_email 'root@localhost'
  source_model TaliaCore::Oai::ActiveSourceModel.new
end
