class ChangeLatoCmsMediaAltTextToTranslations < ActiveRecord::Migration[8.1]
  class MigrationMedia < ActiveRecord::Base
    self.table_name = 'lato_cms_media'
  end

  def up
    change_column :lato_cms_media, :alt_text, :text
    MigrationMedia.reset_column_information

    locale = (LatoCms.config.locales.first || :en).to_s
    MigrationMedia.where.not(alt_text: [nil, '']).find_each do |media|
      media.update_column(:alt_text, { locale => media.alt_text }.to_json)
    end
  end

  def down
    MigrationMedia.reset_column_information

    MigrationMedia.find_each do |media|
      translations = JSON.parse(media.alt_text.presence || '{}') rescue {}
      media.update_column(:alt_text, translations.values.compact.first)
    end
    change_column :lato_cms_media, :alt_text, :string
  end
end
