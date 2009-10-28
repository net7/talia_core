class PopulateUsers < ActiveRecord::Migration
  def self.up
    admins = Role.create :name => 'admin'
    users = Role.create :name => 'user'
    admin = User.create :login => 'admin', :email => 'admin@admins.com',  :password => 'adminadmin', :password_confirmation => 'adminadmin'
    admin.roles << admins
    admins.save!
    users.save!
    admin.save!
  end

  def self.down
  end
end
