class CreateLatoCmsMedia < ActiveRecord::Migration[8.1]
  def change
    create_table :lato_cms_media do |t|
      t.string :name, null: false
      t.string :alt_text
      t.string :media_type, null: false, default: 'file'
      t.timestamps
    end
    add_index :lato_cms_media, :media_type
  end
end
