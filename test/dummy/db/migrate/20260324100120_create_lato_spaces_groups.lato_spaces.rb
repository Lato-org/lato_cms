# This migration comes from lato_spaces (originally 20231102082229)
class CreateLatoSpacesGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :lato_spaces_groups do |t|
      t.string :name
      t.timestamps
    end
  end
end
