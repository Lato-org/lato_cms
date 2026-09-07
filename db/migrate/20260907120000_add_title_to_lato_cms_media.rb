class AddTitleToLatoCmsMedia < ActiveRecord::Migration[8.1]
  def change
    # JSON-serialized {locale => title} hash, same shape as alt_text.
    add_column :lato_cms_media, :title, :text
  end
end
