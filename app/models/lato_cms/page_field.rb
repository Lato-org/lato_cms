module LatoCms
  class PageField < ApplicationRecord
    belongs_to :page, class_name: 'LatoCms::Page'

    has_many :page_field_media, -> { order(:position) }, class_name: 'LatoCms::PageFieldMedia', dependent: :destroy
    has_many :media, through: :page_field_media, class_name: 'LatoCms::Media'

    ATTACHMENT_FIELD_TYPES = %w[file image video gallery].freeze

    validates :template_id, presence: true
    validates :template_component_id, presence: true
    validates :component_id, presence: true
    validates :field_id, presence: true
    validates :field_id, uniqueness: { scope: [:page_id, :template_component_id] }
    validate :media_present_if_required

    REPEATER_ORDER_FIELD_ID = "__repeater_order".freeze

    before_save :parse_value

    def parsed_value
      return nil if value.blank?

      case field_type
      when 'number'
        value.include?('.') ? value.to_f : value.to_i
      when 'boolean'
        value == 'true'
      when 'json'
        JSON.parse(value) rescue value
      when 'date'
        Date.parse(value) rescue value
      when 'datetime'
        DateTime.parse(value) rescue value
      when 'multiselect'
        JSON.parse(value) rescue [value]
      else
        value
      end
    end

    def field_config
      return nil if repeater_order?

      component = LatoCms::TemplateManager.find_component(component_id)
      return nil unless component
      component.dig('fields', base_field_id)
    end

    def repeater_order?
      field_id == REPEATER_ORDER_FIELD_ID
    end

    def repeater_item_id
      return nil unless field_id.to_s.include?('.')

      field_id.to_s.split('.', 2).first
    end

    def base_field_id
      return field_id unless repeater_item_id

      field_id.to_s.split('.', 2).last
    end

    def field_type
      field_config&.dig('type') || 'string'
    end

    def field_name
      field_config&.dig('name') || field_id.to_s.humanize
    end

    def field_required?
      field_config&.dig('required') == true
    end

    def field_settings
      field_config&.dig('settings') || {}
    end

    # Reconciles this field's media references to match the given ordered list
    # of media ids: creates missing join rows, destroys removed ones, and
    # updates `position` to match the given order. Callers must tenant-scope
    # ids before calling this (see PagesController#assign_media_field).
    def replace_media!(media_ids)
      ids = Array(media_ids).reject(&:blank?).map(&:to_s).uniq

      transaction do
        existing = page_field_media.index_by { |pfm| pfm.media_id.to_s }
        (existing.keys - ids).each { |stale_id| existing[stale_id].destroy }
        ids.each_with_index do |media_id, index|
          (existing[media_id] || page_field_media.build(media_id: media_id)).update!(position: index)
        end
      end

      page_field_media.reset
    end

    def as_json(_options = {})
      result = {
        id: id,
        persisted_field_id: field_id,
        field_id: base_field_id,
        field_type: field_type,
        field_name: field_name,
        required: field_required?,
        value: nil,
        attachments: []
      }

      case field_type
      when 'file'
        result[:attachments] = media.map { |m| media_as_json(m) }
      when 'image'
        attached = media.first
        result[:attachments] = attached ? [media_as_json(attached, with_variants: true)] : []
      when 'video'
        attached = media.first
        result[:attachments] = attached ? [video_media_as_json(attached)] : []
      when 'gallery'
        result[:attachments] = media.map { |m| media_as_json(m, with_variants: true) }
      else
        result[:value] = parsed_value
      end

      result
    end

    private

    def media_as_json(m, with_variants: false)
      json = {
        media_id: m.id,
        name: m.name,
        alt_text: m.alt_text,
        filename: m.filename,
        content_type: m.file.attached? ? m.file.content_type : nil,
        byte_size: m.file.attached? ? m.file.byte_size : nil,
        url: m.url
      }
      json[:sizes] = m.variant_urls(field_settings['sizes']) if with_variants
      json
    end

    # Video media json gains a `poster_url` key (nil until the poster job
    # runs) so API consumers get video and poster URLs in a single object.
    def video_media_as_json(m)
      media_as_json(m).merge(poster_url: m.poster_url)
    end

    # A field can only see this validation once media presence is a real
    # association (unlike direct attachments, which used to require a
    # controller-level backstop after save). A brand new required field is
    # saved once, unvalidated, to get an id before media can be attached, then
    # saved again (validated) once media is in place — see
    # PagesController#save_field.
    def media_present_if_required
      return unless ATTACHMENT_FIELD_TYPES.include?(field_type) && field_required?

      errors.add(:base, I18n.t('lato_cms.field_required_attachment_error')) if page_field_media.reload.empty?
    end

    def parse_value
      return if value.blank?

      case field_type
      when 'json'
        begin
          parsed = JSON.parse(value)
          self.value = parsed.to_json
        rescue JSON::ParserError
          errors.add(:value, 'is not valid JSON')
          throw :abort
        end
      when 'boolean'
        self.value = ActiveModel::Type::Boolean.new.cast(value).to_s
      end
    end
  end
end
