class CreateLatoCmsPageFields < ActiveRecord::Migration[8.1]
  def change
    create_table :lato_cms_page_fields do |t|
      t.references :page, null: false, foreign_key: { to_table: :lato_cms_pages }
      t.string :template_id
      t.string :template_component_id
      t.string :component_id
      t.string :field_id
      t.text :value
      t.timestamps
    end
  end
end
