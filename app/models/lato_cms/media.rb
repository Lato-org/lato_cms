require 'base64'

module LatoCms
  class Media < ApplicationRecord
    attr_accessor :actions

    include LatoSpaces::Associable
    include LatoSpaces::AssociableRequired
    include LatoSpaces::AssociableUnique

    MEDIA_TYPES = %w[image video document file].freeze

    # alt_text and title are each stored as a single JSON-serialized
    # {locale => text} hash in their own text column (kept inline rather than
    # in a translations table since these are Media's only translatable
    # attributes). `alt_text`/`title` themselves are overridden below to
    # read/write the current I18n.locale's entry; `alt_text_en`, `title_it`,
    # etc. (one per configured locale) are handled dynamically so forms can
    # render/submit them like any other attribute without predefining a
    # method per locale.
    TRANSLATABLE_ATTRIBUTES = %w[alt_text title].freeze
    TRANSLATION_ACCESSOR = /\A(?<attribute>#{TRANSLATABLE_ATTRIBUTES.join("|")})_(?<locale>[a-z]{2}(?:_[A-Z]{2})?)(?<setter>=)?\z/

    TRANSLATABLE_ATTRIBUTES.each do |attribute|
      define_method(attribute) { |locale = I18n.locale| translations_of(attribute)[locale.to_s].presence }
      define_method("#{attribute}=") { |value| write_translation(attribute, I18n.locale, value) }
      define_method("#{attribute}_translations") { translations_of(attribute) }
      define_method("#{attribute}_translations=") { |hash| self[attribute] = hash.stringify_keys.to_json }
    end

    has_one_attached :file
    has_one_attached :poster_file

    has_many :page_field_media, class_name: 'LatoCms::PageFieldMedia', foreign_key: :media_id, dependent: :destroy
    has_many :page_fields, through: :page_field_media, class_name: 'LatoCms::PageField'

    validates :name, presence: true
    validate :file_attached, on: :create

    before_validation :default_name_from_filename, on: :create
    before_validation :set_media_type, on: :create

    after_create_commit :enqueue_poster_generation, if: :video?
    after_create_commit :enqueue_text_generation, if: -> { image? && LatoCms.config.llm_media_attributes.any? }

    scope :of_type, ->(type) { where(media_type: type) if type.present? }

    # Media missing `attribute` (alt_text or title) in at least one configured
    # locale — the ones worth going back to fill in. Alt text exists only for
    # images, so that filter is scoped to them; a title is editable on every
    # media type.
    #
    # Filtered in Ruby rather than SQL: the translations live as a JSON blob in
    # a text column, and "blank in one locale" is not a predicate any adapter
    # can express without guessing at that serialization (a stored empty string
    # counts as missing too). Only the id and the one column are loaded.
    scope :missing_translation, ->(attribute) {
      attribute = attribute.to_s
      next none unless TRANSLATABLE_ATTRIBUTES.include?(attribute)

      candidates = attribute == "alt_text" ? where(media_type: "image") : all
      locales = LatoCms.config.locales
      incomplete = candidates.select(:id, attribute).reject { |media| locales.all? { |locale| media.public_send(attribute, locale).present? } }

      candidates.where(id: incomplete.map(&:id))
    }

    # Hook picked up by lato's `lato_index_collection` in place of its generic
    # search, whose SQL leaves column names unqualified. The Spaces association
    # joins lato_spaces_groups, which also has a `name` column, so that generic
    # search was ambiguous SQL and the media library's search box raised
    # ("ambiguous column name: name" on SQLite, the same error on Postgres).
    # Qualifying every column here fixes it; alt_text/title are matched as the
    # raw JSON they're stored as, so a hit in any locale counts.
    scope :lato_index_search, ->(search) {
      term = "%#{search.to_s.downcase.strip}%"
      columns = %w[name alt_text title].map { |column| "LOWER(#{table_name}.#{column}) LIKE :term" }

      where(columns.join(" OR "), term: term)
    }

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

    # Every page field referencing this media, grouped by page (sorted by page
    # title). Drives the "used in" list in the admin: a media is shared, so
    # both deleting it and replacing its file are edits to every page listed
    # here, and the admin has to see that before doing either.
    def usages
      page_fields.includes(:page).group_by(&:page).sort_by { |page, _fields| page.title.to_s.downcase }
    end

    def filename
      file.filename.to_s if file.attached?
    end

    def translations_of(attribute)
      JSON.parse(self[attribute].presence || "{}")
    rescue JSON::ParserError
      {}
    end

    def method_missing(name, *args)
      match = TRANSLATION_ACCESSOR.match(name.to_s)
      return super unless match

      if match[:setter]
        write_translation(match[:attribute], match[:locale], args.first)
      else
        translations_of(match[:attribute])[match[:locale]].presence
      end
    end

    def respond_to_missing?(name, include_private = false)
      TRANSLATION_ACCESSOR.match?(name.to_s) || super
    end

    # Frontend URLs of the pages using this media through any field: the
    # absolute URLs handed to the LLM as `{urls}` prompt context, so the model
    # can see where the image is shown. Pages without a frontend URL are left
    # out. Empty right after upload, since nothing references a new media yet.
    def usage_urls
      LatoCms::Page.where(id: page_fields.select(:page_id)).where.not(frontend_url: [nil, ""]).distinct.order(:frontend_url).pluck(:frontend_url)
    end

    def url
      Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true) if file.attached?
    end

    def poster_url
      Rails.application.routes.url_helpers.rails_blob_path(poster_file, only_path: true) if poster_file.attached?
    end

    # Swaps the underlying file while keeping the same record, so every field
    # already referencing this media renders the new file: the point of the
    # action (replace a logo everywhere at once) and its danger at the same
    # time. Active Storage purges the previous blob on attach, the stale video
    # poster is dropped explicitly, and media_type is re-inferred since the
    # new file can be of a different kind. Variants need no cleanup: they are
    # derived from the blob, so the old ones die with it.
    def replace_file!(new_file)
      file.attach(new_file)
      poster_file.purge if poster_file.attached?
      update!(media_type: self.class.infer_media_type(file.content_type))
      enqueue_poster_generation if video?

      true
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

    # Asks the configured OpenAI-compatible LLM for `attribute` (alt_text or
    # title) in every configured locale and merges it in (existing
    # translations for locales the LLM didn't return are kept, the rest are
    # replaced individually). No-op unless the LLM is configured and enabled
    # for that attribute (see LatoCms::Config#llm_generates?) and this media
    # is an image, since the LLM has to look at the file.
    #
    # Best effort by default (`raise_on_error: false`): any failure is logged
    # and swallowed, since the automatic post-upload call site (see
    # GenerateMediaTextJob) must never break the upload over a flaky LLM. The
    # manual "Regenerate with AI" actions run as a Lato::Operation the admin
    # is actively watching, so they pass `raise_on_error: true` to have
    # failures surface there instead of disappearing silently.
    def generate_text!(attribute, raise_on_error: false)
      attribute = attribute.to_s
      raise ArgumentError, "unknown translatable attribute: #{attribute}" unless TRANSLATABLE_ATTRIBUTES.include?(attribute)
      return unless image? && file.attached? && LatoCms.config.llm_generates?(attribute)

      begin
        translations = parse_translations(request_completion(llm_prompt(attribute)))
        raise "The LLM returned no usable #{attribute.humanize.downcase}" if translations.blank?

        public_send("#{attribute}_translations=", translations_of(attribute).merge(translations))
        save!
      rescue StandardError => e
        Rails.logger.warn("LatoCms: failed to generate #{attribute} for media #{id}: #{e.message}")
        raise if raise_on_error
      end
    end

    # Full prompt sent for `attribute`: the custom-or-default task prompt (see
    # LatoCms::Config#llm_prompt) with {languages}/{urls} substituted, plus the
    # engine's fixed response-format contract, appended here rather than left
    # to the prompt so parsing never depends on how a custom prompt is worded.
    def llm_prompt(attribute)
      variables = {
        "languages" => llm_locales.join(", "),
        "urls" => usage_urls.presence&.join(", ") || "none"
      }
      placeholders = /\{(#{LatoCms::Config::LLM_PROMPT_VARIABLES.join("|")})\}/
      task = LatoCms.config.llm_prompt(attribute).gsub(placeholders) { variables[Regexp.last_match(1)] }

      "#{task}\n\nRespond with a single JSON object only, no markdown, no extra text, with exactly these " \
      "keys: #{llm_locales.join(", ")}. Each value is the text written in that language."
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

    # Large uncropped variant for the admin detail view, where the 200x200
    # square thumbnail is too small to actually judge the image. Falls back to
    # the original blob when the file can't be processed (e.g. SVG).
    def preview_url
      return nil unless image? && file.attached?
      return url unless file.variable?

      Rails.application.routes.url_helpers.rails_representation_path(
        file.variant(resize_to_limit: [1200, 1200]), only_path: true
      )
    rescue StandardError => e
      Rails.logger.error("LatoCms: Failed to build preview for media #{id}: #{e.message}")
      url
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
        alt_text_translations: alt_text_translations,
        title: title,
        title_translations: title_translations,
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

    def enqueue_text_generation
      LatoCms::GenerateMediaTextJob.perform_later(media_id: id)
    end

    def write_translation(attribute, locale, value)
      public_send("#{attribute}_translations=", translations_of(attribute).merge(locale.to_s => value))
    end

    def llm_locales
      LatoCms.config.locales.map(&:to_s)
    end

    # Sends the image as a base64 data URI rather than a URL: the file may be
    # stored on a service (or behind auth) the LLM can't reach, so this works
    # regardless of storage backend or app visibility settings.
    def request_completion(prompt)
      LatoCms::LlmClient.chat(messages: [{
        role: "user",
        content: [
          { type: "text", text: prompt },
          { type: "image_url", image_url: { url: "data:#{file.content_type};base64,#{Base64.strict_encode64(file.download)}" } }
        ]
      }])
    end

    def parse_translations(content)
      return {} if content.blank?

      parsed = JSON.parse(content[/\{.*\}/m] || content)
      parsed.slice(*llm_locales).transform_values(&:to_s)
    rescue JSON::ParserError
      {}
    end
  end
end
