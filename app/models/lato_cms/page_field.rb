module LatoCms
  class PageField < ApplicationRecord
    belongs_to :page, class_name: 'LatoCms::Page'

    has_many_attached :files

    validates :template_id, presence: true
    validates :template_component_id, presence: true
    validates :component_id, presence: true
    validates :field_id, presence: true
    validates :field_id, uniqueness: { scope: [:page_id, :template_component_id] }

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

    # A video field stores two attachments in `files`: the video itself and an
    # optional auto-generated poster image. Content type is the discriminator,
    # so no extra column or naming convention is needed.
    def video_attachment
      files.find { |file| file.content_type.to_s.start_with?("video/") }
    end

    def poster_attachment
      files.find { |file| file.content_type.to_s.start_with?("image/") }
    end

    # Generates a poster image from the video via Active Storage previews
    # (ffmpeg) and attaches it alongside the video. Best effort: any failure is
    # logged and the video keeps working without a poster.
    def generate_video_poster!
      video = video_attachment
      return unless video
      return if poster_attachment

      unless video.previewable?
        Rails.logger.warn("LatoCms: video preview unavailable (ffmpeg missing?) for attachment #{video.id}, skipping poster generation")
        return
      end

      preview = video.preview(resize_to_limit: [1280, 720]).processed
      preview.image.blob.open do |file|
        files.attach(io: file, filename: "#{video.filename.base}_poster.jpg", content_type: preview.image.blob.content_type)
      end
    rescue StandardError => e
      Rails.logger.warn("LatoCms: failed to generate video poster for field #{id}: #{e.message}")
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
        result[:attachments] = files.map { |f| attachment_as_json(f) }
      when 'image'
        attached = files.first
        result[:attachments] = attached ? [attachment_as_json(attached, with_variants: true)] : []
      when 'video'
        attached = video_attachment
        result[:attachments] = attached ? [video_attachment_as_json(attached)] : []
      when 'gallery'
        order = value ? (JSON.parse(value) rescue []) : []
        all_files = files.to_a
        ordered = order.any? ? all_files.sort_by { |f| order.index(f.id.to_s) || Float::INFINITY } : all_files
        result[:attachments] = ordered.map { |f| attachment_as_json(f, with_variants: true) }
      else
        result[:value] = parsed_value
      end

      result
    end

    private

    def attachment_as_json(attachment, with_variants: false)
      json = {
        id: attachment.id,
        filename: attachment.filename.to_s,
        content_type: attachment.content_type,
        byte_size: attachment.byte_size,
        url: Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
      }
      json[:sizes] = attachment_variant_urls(attachment) if with_variants
      json
    end

    # Video attachment json gains a `poster_url` key (nil until the poster job
    # runs) so API consumers get video and poster URLs in a single object.
    def video_attachment_as_json(attachment)
      poster = poster_attachment
      attachment_as_json(attachment).merge(
        poster_url: poster && Rails.application.routes.url_helpers.rails_blob_path(poster, only_path: true)
      )
    end

    # Builds a map of { size_name => variant_url } from the field's `settings.sizes`.
    # Variants are processed lazily by Active Storage on first request to their URL.
    def attachment_variant_urls(attachment)
      sizes = field_settings['sizes']
      return {} if sizes.blank? || !sizes.respond_to?(:each_pair) || !attachment.variable?

      url_helpers = Rails.application.routes.url_helpers
      sizes.each_with_object({}) do |(name, opts), acc|
        transformation = variant_transformation(opts)
        next if transformation.blank?

        variant = attachment.variant(transformation)
        acc[name] = url_helpers.rails_representation_path(variant, only_path: true)
      end
    rescue StandardError => e
      Rails.logger.error("LatoCms: Failed to build image variants for attachment #{attachment.id}: #{e.message}")
      {}
    end

    # Maps a size config (width/height/resize) to an Active Storage variant transformation.
    # resize modes: "limit" (default, scale down only), "fit" (scale to fit), "fill" (crop to exact size).
    def variant_transformation(opts)
      opts = {} unless opts.respond_to?(:[])
      dimensions = [opts['width'] || opts[:width], opts['height'] || opts[:height]]
      return nil if dimensions.compact.empty?

      case (opts['resize'] || opts[:resize] || 'limit').to_s
      when 'fill' then { resize_to_fill: dimensions }
      when 'fit' then { resize_to_fit: dimensions }
      else { resize_to_limit: dimensions }
      end
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
