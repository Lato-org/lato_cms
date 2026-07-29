class CreateLatoCmsPageFieldMedia < ActiveRecord::Migration[8.1]
  def change
    create_table :lato_cms_page_field_media do |t|
      t.references :page_field, null: false, foreign_key: { to_table: :lato_cms_page_fields }
      t.references :media, null: false, foreign_key: { to_table: :lato_cms_media }
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :lato_cms_page_field_media, [:page_field_id, :media_id], unique: true
    add_index :lato_cms_page_field_media, [:page_field_id, :position]
  end
end
