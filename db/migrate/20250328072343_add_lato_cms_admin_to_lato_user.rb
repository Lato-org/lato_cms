class AddLatoCmsAdminToLatoUser < ActiveRecord::Migration[7.1]
  def change
    add_column :lato_users, :lato_cms_admin, :boolean, default: false
  end
end
