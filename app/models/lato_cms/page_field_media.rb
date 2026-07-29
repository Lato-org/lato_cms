module LatoCms
  class PageFieldMedia < ApplicationRecord
    belongs_to :page_field, class_name: 'LatoCms::PageField'
    belongs_to :media, class_name: 'LatoCms::Media'

    validates :media_id, uniqueness: { scope: :page_field_id }
  end
end
