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

    before_validation :generate_permalink, on: :create

    has_many :fields, class_name: 'LatoCms::PageField', dependent: :destroy

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

    def build_fields_json(comps)
      fields_by_component = fields.group_by(&:template_component_id)

      comps.each_with_object({}) do |tc, hash|
        component_fields = (fields_by_component[tc[:template_component_id]] || []).index_by(&:field_id)

        hash[tc[:template_component_id]] = {
          component_id: tc[:component_id],
          name: tc[:name],
          fields: (tc[:fields] || {}).each_with_object({}) do |(fid, fconfig), fhash|
            field = component_fields[fid.to_s]
            fhash[fid] = field ? field.as_json : empty_field_json(fid.to_s, fconfig)
          end
        }
      end
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
  end
end
