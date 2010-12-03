# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

module SourcesHelper

  # Link to the index
  def index_link
    link_to 'index', :action => 'index'
  end

  # Checks if the current filter points to the given type
  def current_filter?(ctype)
    (ctype.to_name_s('+') == params[:filter])
  end

  # Links to filter for the given type
  def filter_link_for(ctype)
    link_to ctype.to_name_s, :action => 'index', :filter => ctype.to_name_s('+')
  end

  # Gets the title for a source
  def title_for(source)
    (source[N::DCNS.title].first || source[N::RDF.label].first || N::URI.new(source.uri).local_name.titleize)
  end

  # If the element is a resource, create a link to the local resource page. Otherwise the element
  # will be passed through unmodified 
  def semantic_target(element)
    if(element.respond_to?(:uri))
      uri = N::URI.new(element.uri)
      # TODO: Could check if we are actually dealing with local uris here
      link_to(uri.to_name_s, :controller => 'sources', :action => 'dispatch', :dispatch_uri => uri.local_name)
    else
      element
    end
  end
  
  # Takes a list of data records and creates an image tag for each record, with a
  # symbol image corresponding to the records mime type. The image will link to the
  # record itself.
  #
  # You may modify this to suit your needs, and have a look at the 
  # #data_record_options method while you do.
  def data_icons(data_records)
    result = ''
    data_records.each do |rec|
      link_data = data_record_options(rec)
      result << link_to(
        image_tag("talia_core/#{link_data.first}.png", :alt => rec.location, :title => rec.location),
        { :controller => 'source_data',
          :action => 'show',
          :id => rec.id },
        link_data.last
      )
    end
    
    result
  end
  
  # Creates a little image for each (RDF) type. By default,
  # it will use the same picture for (almost) everything,
  # but you can add additional images easily by adding more entries
  def type_images(types)
    @type_map ||= { 
      N::TALIA.Source => 'source',
      N::FOAF.Group => 'group',
      N::FOAF.Person => 'person'
    }
    result = ''
    types.each do |t|
      image = @type_map[t] || 'source'
      name = t.local_name.titleize
      result << link_to(image_tag("talia_core/#{image}.png", :alt => name, :title => name),
        :action => 'index', :filter => t.to_name_s('+')
      )
    end
    result
  end

  private
  
  # Gives back a result list, the first element being the name of the image file
  # without the extension. The second element is a hash containing options for
  # the link to that data element. E.g. it would be possible to pass a css
  # class giving
  #
  #  ['image_name', {:class => 'my_class'}]
  # 
  # Edit this method to suit your needs
  def data_record_options(record)
    if(record.mime.include?('image/'))
      ['image', {:class => 'cbox_image'}]
    elsif(record.mime.include?('text/'))
      ['text', {:class =>'cbox_inline' }]
    elsif(record.mime == 'application/xml')
      ['text', {:class => 'cbox_inline'}]
    else
      ['gear', {}]
    end
  end

end
