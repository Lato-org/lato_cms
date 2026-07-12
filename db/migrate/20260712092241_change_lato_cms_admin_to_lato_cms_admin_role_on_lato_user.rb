class ChangeLatoCmsAdminToLatoCmsAdminRoleOnLatoUser < ActiveRecord::Migration[8.1]
  def up
    add_column :lato_users, :lato_cms_admin_role, :integer, default: 0, null: false

    # Backfill: true -> 1, false/nil -> 0 (already the column default)
    execute 'UPDATE lato_users SET lato_cms_admin_role = 1 WHERE lato_cms_admin = 1'

    remove_column :lato_users, :lato_cms_admin
  end

  def down
    add_column :lato_users, :lato_cms_admin, :boolean, default: false

    execute 'UPDATE lato_users SET lato_cms_admin = 1 WHERE lato_cms_admin_role = 1'

    remove_column :lato_users, :lato_cms_admin_role
  end
end
