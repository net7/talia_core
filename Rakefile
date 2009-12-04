# This file is only for the tasks that are used only for "standalone" mode, and
# for development. All other tasks go to "tasks/", and are available both 
# in Rails and in standalone mode.

require 'fileutils'
require 'rake/rdoctask'

$: << File.join(File.dirname(__FILE__))

# Load the "public" tasks
load 'tasks/talia_core_tasks.rake'
require 'version'

desc "Setup the environment to test unless ENV['environment'] was already defined."
task :environment do
  ENV['environment'] = "test" if ENV['environment'].nil?
end

desc "Load fixtures into the current database.  Load specific fixtures using FIXTURES=x,y"  
task :fixtures => "talia_core:init" do
  load_fixtures 
end  

desc "Migrate the database through scripts in db/migrate. Target specific version with VERSION=x"  
task :migrate => "talia_core:init" do
  Util::do_migrations 
  puts "Migrations done."
end  

Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.title    = 'Talia Core'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end


begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "talia_core"
    s.summary = "The core elements of the Talia Digital Library system"
    s.email = "ghub@limitedcreativity.org"
    s.homepage = "http://trac.talia.discovery-project.eu/"
    s.description = "This is the core plugin for building a digital library with Talia/Rails."
    s.required_ruby_version = '>= 1.8.6'
    s.authors = ["Danilo Giacomi", "Roberto Tofani", "Luca Guidi", "Daniel Hahn"]
    s.files = FileList["{lib}/**/*", "{generators}/**/*", "{config}/**/*", "{tasks}/**/*", "VERSION.yml"]
    s.extra_rdoc_files = ["README.rdoc", "CHANGES", "LICENSE"]
    s.add_dependency('activerecord', '>= 2.0.5')
    s.add_dependency('activesupport', '>= 2.0.5')
    s.add_dependency('activerdf_net7', '>= 1.6.13')
    s.add_dependency('assit', '>= 0.1.2')
    s.add_dependency('semantic_naming', '>= 2.0.6')
    s.add_dependency('averell23-bj', '>= 1.0.2')
    s.add_dependency('hpricot', '>= 0.6.1')
    s.add_dependency('oai', '>= 0.0.12')
    s.add_dependency('builder', '>= 2.1.2')
    s.add_dependency('optiflag', '>= 0.6.5')
    s.add_dependency('rake', '>= 0.7.1')
    s.requirements << "rdflib (Redland RDF) + Ruby bindings (for Redland store)"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end


begin
  require 'gokdok'
  Gokdok::Dokker.new do |gd|
    gd.remote_path = ''
  end
rescue LoadError
  puts "Gokdoc not available. Install it with: gem install gokdok"
end
