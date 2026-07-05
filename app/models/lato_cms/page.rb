module LatoCms
  class Page < ApplicationRecord
    include LatoSpaces::Associable
    include LatoSpaces::AssociableRequired
    include LatoSpaces::AssociableUnique

    attr_accessor :actions

    validates :title, presence: true
    validates :locale, presence: true, inclusion: { in: ->(page) { LatoCms.config.locales.map(&:to_s) } }
    validates :permalink, presence: true, format: { with: /\A\/([a-zA-Z0-9\-_]+(\/[a-zA-Z0-9\-_]+)*)?\z/, message: 'must start with / and contain only letters, numbers, hyphens, and underscores' }
    validate :permalink_unique_within_lato_spaces_group
    validate :locale_unique_within_translation_group

    before_validation :generate_permalink, on: :create

    has_many :fields, class_name: 'LatoCms::PageField', dependent: :destroy

    # ── Translations ────────────────────────────────────────────────────────
    # Pages sharing the same translation_group_id (within the same spaces group)
    # are translations of each other, at most one per locale.

    # Sibling pages linked as translations of this page.
    def translations
      return LatoCms::Page.none if translation_group_id.blank?

      LatoCms::Page
        .for_lato_spaces_group(lato_spaces_group_id)
        .where(translation_group_id: translation_group_id)
        .where.not(id: id)
    end

    # The linked translation for a given locale, if any.
    def translation_for(locale)
      translations.find_by(locale: locale.to_s)
    end

    # Pages of a given locale that can be linked to this page: same spaces group,
    # not this page, and not already part of any translation group.
    def translation_candidates(locale)
      LatoCms::Page
        .for_lato_spaces_group(lato_spaces_group_id)
        .where(locale: locale.to_s, translation_group_id: nil)
        .where.not(id: id)
    end

    # Links another page as a translation of this one, merging any existing
    # groups so all members share a single translation_group_id.
    def link_translation(other_page)
      return false unless other_page && other_page.id != id
      return false unless other_page.lato_spaces_group_id == lato_spaces_group_id

      group_id = translation_group_id.presence || other_page.translation_group_id.presence || SecureRandom.uuid
      old_group_id = other_page.translation_group_id.presence

      transaction do
        update!(translation_group_id: group_id)
        # Re-point every member of the other page's former group to keep groups merged.
        if old_group_id && old_group_id != group_id
          LatoCms::Page
            .for_lato_spaces_group(lato_spaces_group_id)
            .where(translation_group_id: old_group_id)
            .update_all(translation_group_id: group_id)
        else
          other_page.update!(translation_group_id: group_id)
        end
      end

      true
    end

    # Removes a page from this page's translation group.
    def unlink_translation(other_page)
      return false unless other_page && other_page.translation_group_id == translation_group_id

      other_page.update!(translation_group_id: nil)
      true
    end

    def template
      LatoCms::TemplateManager.find_template(template_id)
    end

    def template_name
      template&.dig('name') || template_id
    end

    def template_available?
      template_id.blank? || template.present?
    end

    def template_components
      return [] unless template
      LatoCms::TemplateManager.resolve_template_components(template)
    end

    def component_enabled?(template_component_id, default: true)
      value = (component_states || {})[template_component_id.to_s]
      return default if value.nil?

      value == true
    end

    def component_required?(template_component_id)
      tc = template_components.find { |component| component[:template_component_id] == template_component_id.to_s }
      tc && tc[:required] == true
    end

    def component_effectively_enabled?(template_component_id, default: true)
      return true if component_required?(template_component_id)

      component_enabled?(template_component_id, default: default)
    end

    def set_component_enabled(template_component_id, enabled)
      key = template_component_id.to_s
      self.component_states = (component_states || {}).merge(key => ActiveModel::Type::Boolean.new.cast(enabled))
    end

    def as_json(options = {})
      data = {
        id: id,
        title: title,
        permalink: permalink,
        locale: locale,
        template_id: template_id,
        template_name: template_name,
        frontend_url: frontend_url,
        translations: translations_json,
        created_at: created_at,
        updated_at: updated_at
      }

      if options[:include_fields]
        fields.load unless fields.loaded?
        data[:fields] = build_fields_json(template_components.select { |tc| component_effectively_enabled?(tc[:template_component_id]) })
      end

      data
    end

    private

    # Map of locale => permalink/id for linked translations, for API consumers.
    def translations_json
      translations.each_with_object({}) do |page, hash|
        hash[page.locale] = { id: page.id, permalink: page.permalink, frontend_url: page.frontend_url }
      end
    end

    def build_fields_json(comps)
      fields_by_component = fields.group_by(&:template_component_id)

      comps.each_with_object({}) do |tc, hash|
        component_fields = (fields_by_component[tc[:template_component_id]] || []).index_by(&:field_id)

        hash[tc[:template_component_id]] = {
          component_id: tc[:component_id],
          name: tc[:name],
          fields: tc[:repeater] ?
            build_repeater_fields_json(tc, fields_by_component[tc[:template_component_id]] || []) :
            build_component_fields_json(tc, component_fields)
        }
      end
    end

    def build_component_fields_json(tc, component_fields)
      (tc[:fields] || {}).each_with_object({}) do |(fid, fconfig), fhash|
        field = component_fields[fid.to_s]
        fhash[fid] = field ? field.as_json : empty_field_json(fid.to_s, fconfig)
      end
    end

    def build_repeater_fields_json(tc, component_fields)
      order = repeater_order(component_fields)
      fields_by_item = component_fields.reject(&:repeater_order?).group_by(&:repeater_item_id)
      item_ids = order.presence || fields_by_item.keys.compact

      item_ids.filter_map do |item_id|
        item_fields = (fields_by_item[item_id] || []).index_by(&:base_field_id)
        next if item_fields.blank?

        {
          id: item_id,
          fields: build_component_fields_json(tc, item_fields)
        }
      end
    end

    def repeater_order(component_fields)
      order_field = component_fields.find(&:repeater_order?)
      return [] unless order_field&.value.present?

      JSON.parse(order_field.value)
    rescue JSON::ParserError
      []
    end

    def empty_field_json(fid, fconfig)
      {
        id: nil,
        field_id: fid,
        field_type: fconfig['type'] || 'string',
        field_name: fconfig['name'] || fid.humanize,
        required: fconfig['required'] == true,
        value: nil,
        attachments: []
      }
    end

    def generate_permalink
      return if title.blank?
      return if permalink.present?

      base = "/#{title.parameterize}"
      candidate = base
      counter = 1

      while LatoCms::Page.for_lato_spaces_group(self.lato_spaces_group_id).where(permalink: candidate).where.not(id: id).exists?
        candidate = "#{base}-#{counter}"
        counter += 1
      end

      self.permalink = candidate
    end

    def permalink_unique_within_lato_spaces_group
      other_pages_with_same_permalink = LatoCms::Page.for_lato_spaces_group(self.lato_spaces_group_id).where(permalink: permalink).where.not(id: id)
      if other_pages_with_same_permalink.count.positive?
        errors.add(:permalink, :taken)
      end
    end

    def locale_unique_within_translation_group
      return if translation_group_id.blank?

      conflict = LatoCms::Page
        .for_lato_spaces_group(lato_spaces_group_id)
        .where(translation_group_id: translation_group_id, locale: locale)
        .where.not(id: id)
        .exists?

      errors.add(:locale, :taken) if conflict
    end
  end
end
