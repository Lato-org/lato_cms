module LatoCms
  class PageField < ApplicationRecord
    belongs_to :page, class_name: 'LatoCms::Page'

    has_many :page_field_media, -> { order(:position) }, class_name: 'LatoCms::PageFieldMedia', dependent: :destroy
    has_many :media, through: :page_field_media, class_name: 'LatoCms::Media'

    ATTACHMENT_FIELD_TYPES = %w[file image video gallery].freeze
    RICH_TEXT_TAGS = %w[a b blockquote br code div em h1 h2 h3 h4 h5 h6 hr i img li ol p pre s span strike strong u ul].freeze
    RICH_TEXT_ATTRIBUTES = %w[href title style src alt width height].freeze

    # Field types that hold free-form text, used to decide what a
    # "clone & translate" (see PagesController#clone_component_fields) sends
    # to the LLM. Everything else (select/multiselect options, booleans,
    # numbers, dates, colors, json, custom) is either a fixed choice or
    # structured data that translation would corrupt.
    TRANSLATABLE_FIELD_TYPES = %w[string textarea text].freeze

    validates :template_id, presence: true
    validates :template_component_id, presence: true
    validates :component_id, presence: true
    validates :field_id, presence: true
    validates :field_id, uniqueness: { scope: [:page_id, :template_component_id] }
    validate :media_present_if_required
    validate :value_matches_field_type

    REPEATER_ORDER_FIELD_ID = "__repeater_order".freeze

    before_save :parse_value

    def parsed_value
      return nil if value.blank?

      case field_type
      when 'text'
        self.class.sanitize_rich_text(value)
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

    RICH_TEXT_ALIGNMENTS = %w[left center right justify].freeze
    COLOR_FORMAT = /\A#(\h{3}|\h{6})\z/

    # Same allowlist as the editor's client-side sanitizer: `style` is reduced
    # to text-align, the only style the toolbar produces, so a value posted
    # outside the editor cannot keep arbitrary CSS either.
    def self.sanitize_rich_text(value)
      html = ActionController::Base.helpers.sanitize(value, tags: RICH_TEXT_TAGS, attributes: RICH_TEXT_ATTRIBUTES).to_s
      return String.new(html) unless html.include?('style=')

      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      fragment.css('[style]').each do |element|
        alignment = element['style'][/(?:\A|;)\s*text-align\s*:\s*([a-z]+)/i, 1].to_s.downcase
        RICH_TEXT_ALIGNMENTS.include?(alignment) ? element['style'] = "text-align: #{alignment};" : element.remove_attribute('style')
      end
      String.new(fragment.to_html)
    end

    # The field definition comes from the template this field was saved
    # under, never from the stored component_id: that id used to be taken
    # from the request, and a forged one turned a `text` field (sanitized)
    # into a `string` one (not sanitized).
    def field_config
      return nil if repeater_order?

      LatoCms::TemplateManager.find_template_component_fields(template_id, template_component_id)&.dig(base_field_id)
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
        alt_text: m.alt_text(page.locale),
        title: m.title(page.locale),
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

    # Server-side counterpart of the browser checks (`required`, option
    # lists, number and color inputs): a request built by hand skips those,
    # and the API hands the stored value to the frontend as-is.
    def value_matches_field_type
      return if repeater_order? || ATTACHMENT_FIELD_TYPES.include?(field_type)

      if value_blank_for_type?
        errors.add(:value, :blank) if field_required?
        return
      end

      case field_type
      when 'number'
        errors.add(:value, :not_a_number) unless value.to_s.strip.match?(/\A-?\d+(\.\d+)?\z/)
      when 'color'
        errors.add(:value, :invalid) unless value.to_s.match?(COLOR_FORMAT)
      when 'select'
        errors.add(:value, :inclusion) if option_values.any? && !option_values.include?(value.to_s)
      when 'multiselect'
        errors.add(:value, :inclusion) if option_values.any? && (Array(parsed_value).map(&:to_s) - option_values).any?
      when 'date', 'datetime'
        errors.add(:value, :invalid) unless valid_date_value?
      end
    end

    def value_blank_for_type?
      return true if value.blank?

      field_type == 'multiselect' && Array(parsed_value).compact_blank.empty?
    end

    def valid_date_value?
      field_type == 'date' ? Date.iso8601(value.to_s) : DateTime.parse(value.to_s)
      true
    rescue ArgumentError, Date::Error
      false
    end

    # `options` may list plain strings or `{ value:, label: }` hashes.
    def option_values
      Array(field_settings['options']).map { |option| (option.is_a?(Hash) ? option['value'] : option).to_s }
    end

    def parse_value
      return if value.blank?

      case field_type
      when 'text'
        self.value = self.class.sanitize_rich_text(value)
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
