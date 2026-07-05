class AddTranslationGroupIdToLatoCmsPages < ActiveRecord::Migration[8.1]
  def change
    # Pages sharing the same translation_group_id are translations of each other
    # (one page per locale within a group). Nil means the page is not linked.
    add_column :lato_cms_pages, :translation_group_id, :string
    add_index :lato_cms_pages, :translation_group_id
  end
end
