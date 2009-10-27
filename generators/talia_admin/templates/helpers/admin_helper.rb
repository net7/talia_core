module AdminHelper
  def admin_toolbar
    widget(:toolbar, :buttons => [ 
        ["Home", {:controller => 'source', :action => 'show', :id => 'Lucca'}], 
        ["Admin", {:action => 'index'} ],
        ["Sources", {:controller => 'admin/sources' }],
        ["Users", { :controller => 'admin/users'} ],
        ["Print Page", "javascript:print();"]
      ] )
  end
  
  # Returns the title for the whole page. This returns the value
  # set in the controller, or a default value
  def page_title
    @page_title || TaliaCore::SITE_NAME
  end
  
  # Show each <tt>flash</tt> status (<tt>:notice</tt>, <tt>:error</tt>) only if it's present.
  def show_flash
    [:notice, :error].collect do |status|
      %(<div id="#{status}">#{flash[status]}</div>) unless flash[status].nil?
    end
  end
  
  # Defines the pages that are visible in the menu
  def active_pages
    %w(users background sources) # translations not working at the moment, templates not ready for generic use
  end
  
end
