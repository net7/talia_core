ActionController::Routing::Routes.draw do |map|
  map.logout '/logout', :controller => 'sessions', :action => 'destroy'
  map.login '/login', :controller => 'sessions', :action => 'new'
  map.register '/register', :controller => 'users', :action => 'create'
  map.signup '/signup', :controller => 'users', :action => 'new'
  map.resources :users

  map.resource :session

  map.logout '/logout', :controller => 'sessions', :action => 'destroy'
  map.login '/login', :controller => 'sessions', :action => 'new'
  map.register '/register', :controller => 'users', :action => 'create'
  map.signup '/signup', :controller => 'users', :action => 'new'
  map.resources :users

  map.resource :session

  map.logout '/logout', :controller => 'sessions', :action => 'destroy'
  map.login '/login', :controller => 'sessions', :action => 'new'
  map.register '/register', :controller => 'users', :action => 'create'
  map.signup '/signup', :controller => 'users', :action => 'new'
  map.resources :users

  map.resource :session

  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # See how all your routes lay out with "rake routes"
  
  # Default route
  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.

  map.namespace :admin do |admin|
    admin.resources :translations, :collection => { :search => :get }
    admin.resources :users, :active_scaffold => true
    admin.resources :sources, :active_scaffold => true
    admin.resources :locales
    admin.resources :background, :active_scaffold => true
    admin.resources :custom_templates, :active_scaffold => true
    admin.resources :data_records, :active_scaffold => true
  end

  map.connect 'sources/auto_complete_for_uri', :controller => 'sources', :action => 'auto_complete_for_uri'

  # Routes for login and users handling
  map.resources :users
  map.login  'login',  :controller => 'sessions', :action => 'create'
  map.logout 'logout', :controller => 'sessions', :action => 'destroy'
  map.admin  'admin',  :controller => 'admin',    :action => 'index'
  map.open_id_complete 'session', :controller => 'sessions', :action => 'create', :requirements => { :method => :get }
  map.resource :session
  map.resources :languages, :member => { :change => :get }

  # Routes for the ontologies
  map.resources :ontologies
  
  # Routes for the sources
  map.resources :sources, :requirements => { :id => /.+/  }
  
  # Routes for types
  map.resources :types

  # Routes for hyperedition previews
  map.connect '/preview', :controller => 'preview'
  
  # Routes for the source data
  map.connect 'source_data/:id', :controller => 'source_data',
    :action => 'show'
  map.connect 'source_data/:type/:location', :controller => 'source_data',
    :action => 'show_tloc',
    :requirements => { :location => /[^\/]+/ } # Force the location to match also filenames with points etc.

  map.resources :data_records, :controller => 'source_data'
  
  # Routes for the widget engine
  # map.resources :widgeon, :collection => { :callback => :all } do |widgets|
  #   widgets.connect ':file', :controller => 'widgeon', :action => 'load_file', :requirements => { :file => %r([^;,?]+) }
  # end
    
  # Routes for import
  map.connect 'import/:action', :controller => 'import', :action => 'start_import'

  # Default semantic dispatch
  map.connect ':dispatch_uri.:format', :controller => 'sources', :action => 'dispatch',
    :requirements => { :dispatch_uri => /[^\.]+/ }

  # map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'
  
  
end