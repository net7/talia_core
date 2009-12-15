require 'hpricot'

module TaliaUtil

  # Helper methods that will be used during import job runs.
  # The import jobs may use the following environment parameters:
  #
  # [*base_url*] The base URL or directory. This will be prefixed to all urls, or if it is 
  #              a local directory, it will be made the current directory during the import
  # [*index*] If given, the importer will try to read this document. While this will still
  #           support the old-style "hyper" format with sigla, it should usually contain a
  #           main element called "index" followed by "url" entries. 
  # [*xml*] URL of an XML file to import. This is incompatible with the "index" option. 
  #         If neither "xml" nor "index" are given, the class will try to read the XML data from
  #         STDIN
  # [*importer*] Name of the importer class to be used for the data. Uses the default class if not given
  # [*reset_store*] - If this is set, the data store will be cleared before the import
  # [*user*] Username for HTTP authentication, if required
  # [*pass*] Password for HTTP authentication, if required
  # [*callback*] Name of a class. If given, the import will call the #before_import and #after_import
  #              methods on an object of that class. The call will receive a block which may be
  #              yielded to for each progress step and which can receive the overall number of
  #              steps
  # [*extension*] Only used with index files; file extension to use
  # [*duplicates*] How to deal with elements that already exist in the datastore. This may be
  #                set to one of the following options (default: :skip):
  #                * :add - Database fields will be updated and the system will add semantic
  #                  properties as additional values, without removing any of the existing
  #                  semantic relations. Example: If the data store already
  #                  contains a title for an element, and the import file contains another
  #                  for that element, the element will have two titles after the import. 
  #                  The system will not check for duplicates. Files will always be imported
  #                  in addition to the existing ones.
  #                * :update - Database fields will be updated, and semantic properties will
  #                  be overwritten with the new value(s). Semantic properties that are not
  #                  included in the import data will be left untouched. In the example above,
  #                  the element would only contain the new title. If the element also contained
  #                  author information, and no author information was in the import file, the
  #                  existing author information will be untouched. Existing files are replaced
  #                  if the import contains new files
  #                * :overwrite - Database fields will be updated. All semantic data will be
  #                  deleted before the import. Files are always removed.
  #                * :skip - If an element already exists, the import will be skipped.
  #
  # [*trace*] Enable tracing output for errors. (By default, this takes the rake task's setting
  #           if possible)
  class ImportJobHelper

    include IoHelper

    attr_reader :importer, :credentials, :index_data, :xml_data, :reset, :callback, :base_url, :message_stream, :progressor, :duplicates, :trace

    # The message_stream will be used for printing progress messages
    def initialize(message_stream = STDOUT, progressor = TaliaCore::BackgroundJobs::Job)
      @trace = (defined?(Rake) ? Rake.application.options.trace : false) || ENV['trace']
      @progressor = progressor
      @message_stream = message_stream
      @duplicates = ENV['duplicates'].to_sym if(ENV['duplicates'])
      @importer = ENV['importer'] || 'TaliaCore::ActiveSourceParts::Xml::SourceReader'
      @credentials = { :http_basic_authentication => [ENV['user'], ENV['pass']] } unless(ENV['user'].blank?)
      assit(!(ENV['xml'] && ENV['index']), 'Not both xml and index parameters allowed')
      @reset = ['yes', 'true'].include?(ENV['reset_store'].downcase) if(ENV['reset_store'])

      @base_url = ENV['base_url'].blank? ? '' : ENV['base_url']
      if(base_url && File.directory?(base_url))
        message_stream.puts "Setting directory to #{base_url}"
        FileUtils.cd(base_url)
      end

      init_data
      
      @callback = ENV['callback'].classify.constantize.new unless(ENV['callback'].blank?)
      
      message_stream.puts "Registered callback (#{callback.class.name}) - (#{callback.respond_to?(:before_import)}|#{callback.respond_to?(:after_import)})" if(callback)
      
      callback.progressor = progressor if(callback && callback.respond_to?(:'progressor='))
    end

    def init_data
      if(ENV['index'].blank?)
        @xml_data = if(ENV['xml'].blank?)
          STDIN.read
        else
          xml_url = ENV['xml']
          xml_url = base_url + xml_url unless(File.exists?(xml_url))
          @true_root = base_for(xml_url)
          open_generic(xml_url, credentials) { |io| io.read }
        end
      else
        index = make_url_from(ENV['index'])
        @index_data = open_generic(index, credentials) { |io| io.read }
      end
    end

    def do_import
      if(reset)
        TaliaUtil::Util.full_reset
        puts "Data Store has been completely reset"
      end
      errors = []
      run_callback(:before_import)
      if(index_data)
        import_from_index(errors)
      else
        puts "Importing from single data file."
        TaliaCore::ActiveSource.create_from_xml(xml_data, :progressor => progressor, :reader => importer, :base_file_uri => @true_root, :errors => errors, :duplicates => duplicates)
      end
      if(errors.size > 0)
        puts "WARNING: #{errors.size} errors during import:"
        errors.each { |e| print_error e }
      end
      run_callback(:after_import)
    end

    def print_error(e)
      puts e.message
      puts e.backtrace if(trace)
    end

    def import_from_index(errors)
      doc = Hpricot.XML(index_data)
      hyper_format = (doc.root.name == 'sigla')
      elements = hyper_format ? (doc/:siglum) : (doc/:url)
      puts "Import from Index file, #{elements.size} elements"
      # Read the Attributes from the urls
      source_attributes = []
      my_importer = importer.classify.constantize
      progressor.run_with_progress('Reading w/ index', elements.size) do |prog|
        elements.each do |element|
          url = make_url_from("#{element.inner_text}#{ENV['extension']}")
          begin
            this_attribs = my_importer.sources_from_url(url, credentials)
            source_attributes = source_attributes + this_attribs
          rescue Exception => e
            message_stream.puts "Problem importing #{url} (#{e.message})"
            message_stream.puts e.backtrace
          end
          prog.inc
        end
      end
      # Write the data
      TaliaCore::ActiveSource.progressor = progressor
      TaliaCore::ActiveSource.create_multi_from(source_attributes, :errors => errors, :duplicates => duplicates)
    end

    def make_url_from(url)
      return url if(File.exist?(url))
      "#{base_url}#{url}"
    end

    def run_callback(name)
      if(callback && callback.respond_to?(name))
        puts "Running callback #{name}"
        callback.send(name)
      end
    end


  end # End class
end