module LatoCms
  class Media < ApplicationRecord
    include LatoSpaces::Associable
    include LatoSpaces::AssociableRequired
    include LatoSpaces::AssociableUnique

    MEDIA_TYPES = %w[image video document file].freeze

    has_one_attached :file
    has_one_attached :poster_file

    has_many :page_field_media, class_name: 'LatoCms::PageFieldMedia', foreign_key: :media_id, dependent: :destroy
    has_many :page_fields, through: :page_field_media, class_name: 'LatoCms::PageField'

    validates :name, presence: true
    validate :file_attached, on: :create

    before_validation :default_name_from_filename, on: :create
    before_validation :set_media_type, on: :create

    after_create_commit :enqueue_poster_generation, if: :video?

    scope :of_type, ->(type) { where(media_type: type) if type.present? }

    def self.infer_media_type(content_type)
      content_type = content_type.to_s
      return 'image' if content_type.start_with?('image/')
      return 'video' if content_type.start_with?('video/')
      return 'document' if content_type == 'application/pdf' || content_type.start_with?('application/vnd') || content_type.start_with?('text/')

      'file'
    end

    def self.variant_transformation(opts)
      opts = {} unless opts.respond_to?(:[])
      dimensions = [opts['width'] || opts[:width], opts['height'] || opts[:height]]
      return nil if dimensions.compact.empty?

      case (opts['resize'] || opts[:resize] || 'limit').to_s
      when 'fill' then { resize_to_fill: dimensions }
      when 'fit' then { resize_to_fit: dimensions }
      else { resize_to_limit: dimensions }
      end
    end

    def image?
      media_type == 'image'
    end

    def video?
      media_type == 'video'
    end

    def usage_count
      page_field_media.count
    end

    def filename
      file.filename.to_s if file.attached?
    end

    def url
      Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true) if file.attached?
    end

    def poster_url
      Rails.application.routes.url_helpers.rails_blob_path(poster_file, only_path: true) if poster_file.attached?
    end

    # Best effort: generates a poster from the video via Active Storage previews
    # (ffmpeg). Any failure is logged, the video keeps working without a poster.
    def generate_video_poster!
      return unless video? && file.attached?
      return if poster_file.attached?

      unless file.previewable?
        Rails.logger.warn("LatoCms: video preview unavailable (ffmpeg missing?) for media #{id}, skipping poster generation")
        return
      end

      preview = file.preview(resize_to_limit: [1280, 720]).processed
      preview.image.blob.open do |f|
        poster_file.attach(io: f, filename: "#{file.filename.base}_poster.jpg", content_type: preview.image.blob.content_type)
      end
    rescue StandardError => e
      Rails.logger.warn("LatoCms: failed to generate video poster for media #{id}: #{e.message}")
    end

    # Fixed small variant used across admin UI (Media index, picker grid, field
    # preview) regardless of a field's own `settings.sizes` (used only by the
    # public API, see `variant_urls`).
    def thumbnail_url
      return nil unless image? && file.attached? && file.variable?

      Rails.application.routes.url_helpers.rails_representation_path(
        file.variant(resize_to_fill: [200, 200]), only_path: true
      )
    rescue StandardError => e
      Rails.logger.error("LatoCms: Failed to build thumbnail for media #{id}: #{e.message}")
      nil
    end

    # Builds a map of { size_name => variant_url } from a field's `settings.sizes`
    # config. The config is field-owned (different fields can request different
    # crops of the same reused Media); the mechanics live here since Media owns
    # the attached blob.
    def variant_urls(sizes_config)
      return {} if sizes_config.blank? || !sizes_config.respond_to?(:each_pair) || !file.attached? || !file.variable?

      url_helpers = Rails.application.routes.url_helpers
      sizes_config.each_with_object({}) do |(name, opts), acc|
        transformation = self.class.variant_transformation(opts)
        next if transformation.blank?

        acc[name] = url_helpers.rails_representation_path(file.variant(transformation), only_path: true)
      end
    rescue StandardError => e
      Rails.logger.error("LatoCms: Failed to build image variants for media #{id}: #{e.message}")
      {}
    end

    def as_json(_options = {})
      {
        id: id,
        name: name,
        alt_text: alt_text,
        media_type: media_type,
        filename: filename,
        content_type: file.attached? ? file.content_type : nil,
        byte_size: file.attached? ? file.byte_size : nil,
        url: url,
        thumbnail_url: thumbnail_url,
        poster_url: poster_url,
        usage_count: usage_count,
        created_at: created_at,
        updated_at: updated_at
      }
    end

    private

    def file_attached
      errors.add(:file, :blank) unless file.attached?
    end

    def default_name_from_filename
      self.name = file.filename.to_s if name.blank? && file.attached?
    end

    def set_media_type
      self.media_type = self.class.infer_media_type(file.content_type) if file.attached?
    end

    def enqueue_poster_generation
      LatoCms::GenerateVideoPosterJob.perform_later(id)
    end
  end
end
