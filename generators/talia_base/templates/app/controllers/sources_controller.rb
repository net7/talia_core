class SourcesController < ApplicationController
  include TaliaCore
  
  before_filter :setup_format, :except => [ 'dispatch', 'index' ]

  PER_PAGE = 10
  
  # GET /sources
  # GET /sources.xml
  def index
    @rdf_types ||= self.class.source_types

    conditions = if(filter = params[:filter])
      { :find_through => [N::RDF.type, N::URI.make_uri(filter, '+')] }
    else
      {}
    end
    if(will_paginate?)
      @sources = TaliaCore::ActiveSource.paginate(conditions.merge(:page => params[:page]))
    else
      @sources = TaliaCore::ActiveSource.find(:all, conditions)
    end
  end

  # GET /sources/1
  # GET /sources/1.xml
  def show
    raise(ActiveRecord::RecordNotFound) unless(ActiveSource.exists?(params[:id]))
    @source = ActiveSource.find(params[:id])
    respond_to do |format|
      format.xml { render :text => @source.to_xml }
      format.rdf { render :text => @source.to_rdf }
      format.html { render }
    end
  end

  # GET /sources/1/name
  def show_attribute
    headers['Content-Type'] = Mime::TEXT
    attribute = TaliaCore::Source.find(params[:source_id])[params[:attribute]]
    status = '404 Not Found' if attribute.nil?
    render :text => attribute.to_s, :status => status
  end

  # GET /sources/1/foaf/friend
  def show_rdf_predicate
    headers['Content-Type'] = Mime::TEXT
    predicates = TaliaCore::Source.find(params[:id]).predicate(params[:namespace], params[:predicate])
    if predicates.nil?
      # This is a workaround: when predicates is nil it tries to render a template with the name of this method.
      predicates = ''
      status = '404 Not Found'
    end
    render :text => predicates, :status => status
  end
  
  # Semantic dispatch. This will try to auto-handle URLs that are not otherwise
  # caught and see if a source exists. If the source exists, the system will
  # try to figure out how to render it. In this case, all relations on the source are
  # automaticaly prefetched when it's loaded.
  def dispatch
    @source = TaliaCore::ActiveSource.find(params[:dispatch_uri], :prefetch_relations => true)
    @types = @source.types
    @types.each do |type|
      caller = type.to_name_s('_')
      self.send(caller) if(self.respond_to?(caller))
    end
    respond_to do |format|
      format.xml { render :text => @source.to_xml }
      format.rdf { render :text => @source.to_rdf }
      format.html { render :action => template_for(@source) }
    end
  end
  
  private 

  # Hack around routing limitation: We use the @ instead of the dot as a delimiter
  def setup_format
    split_id = params[:id].split('@')
    assit(split_id.size <= 2)
    params[:id] = split_id.first
    params[:format] = (split_id.size > 1) ? split_id.last : 'html'
  end
  
  private

  # Indicates if pagination is available.
  def will_paginate?
    return @will_paginate if(@will_paginate != nil)
    return true if(defined?(WillPaginate))
    begin
      require 'rubygems'
      require 'will_paginate'
      @will_paginate = true
    rescue MissingSourceFile
      logger.warn('will_paginate cannot be found, pagination is not available')
      @will_paginate = false
    end
    @will_paginate
  end

  # Returns the first matching template for the given source.
  #
  # * If the source has RDF types, it will try to find the first template
  #   that matches one of the RDF types. If one is found is it returned.
  # * Otherwise, it will look for a default template matching the source's
  #   runtime class.
  # * If no other template is found, this will return the default template name
  def template_for(source)
    source.types.each do |type|
      if(template = template_map[type.uri.to_s])
        return template
      end
    end
    template = template_map[source.class.name.demodulize]
    template ? template : "semantic_templates/default/default"
  end

  def template_map
    self.class.template_map
  end

  class << self

    def template_map
      return @template_map if(@template_map && (ActiveSupport::Dependencies.mechanism != :require))
      @template_map = {}
      Dir["#{template_path}/*"].each do |dir|
        next unless(File.directory?(dir) && File.basename(dir) != 'default')
        map_templates_in(dir)
      end
      map_default_templates
      @template_map
    end

    def template_path
      @template_path ||= File.join(RAILS_ROOT, 'app', 'views', 'sources', 'semantic_templates')
    end

    def source_types
      return @source_types if(@source_types)
      @source_types = Query.new(N::URI).select(:type).distinct.where(:source, N::RDF.type, :type).execute
      @source_types
    end

    private

    # Creates a hash that can be used for looking up the correct semantic
    # template for a source. This scans the template directory and connects
    # the templates to the right RDF types
    def map_templates_in(dir)
      namespace = N::Namespace[File.basename(dir)]
      namsp_object = N::Namespace[namespace]
      TaliaCore.logger.warn("WARNING: Template files in #{dir} are never used, no namespace: #{namespace}.") unless(namesp_object)
      return unless(namesp_object)
      Dir["#{dir}/*"].each do |template|
        next unless(File.file?(template))
        template = template_basename(template)
        @template_map[(namsp_object + template).to_s] = "semantic_templates/#{namespace}/#{template}"
      end
    end
  
    # Map the "default" templates to runtime types
    def map_default_templates
      Dir["#{template_path}/default/*"].each do |templ|
        templ_name = template_basename(templ)
        next unless(File.file?(templ) && templ_name != 'default' )
        @template_map[templ_name.camelize] = "semantic_templates/default/#{templ_name}"
      end
    end
  
    # Get the "basename" of a template
    def template_basename(template_file)
      base = File.basename(template_file)
      base.gsub(/\..*\Z/, '')
    end

  end
  
end
