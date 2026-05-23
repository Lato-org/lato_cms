class CreateLatoCmsPages < ActiveRecord::Migration[8.1]
  def change
    create_table :lato_cms_pages do |t|
      t.string :permalink, null: false, index: true
      t.string :locale, null: false, index: true
      t.string :title, null: false
      t.string :frontend_url
      t.string :template_id
      t.timestamps
    end
  end
end
