module Admin::TaliaSourcesHelper
  
  def all_collections
    TaliaCollection.find(:all, :limit => 20)
  end
  
end