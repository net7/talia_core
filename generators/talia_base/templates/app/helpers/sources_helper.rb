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
    (source[N::DCNS.title].first || N::URI.new(source.uri).local_part)
  end

end
