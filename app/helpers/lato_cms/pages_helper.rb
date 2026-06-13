module LatoCms
  module PagesHelper
    BUILTIN_FIELD_TYPES = %w[string textarea text number date datetime boolean select multiselect color json file image gallery].freeze

    # Returns the path for an Active Storage attachment.
    # Using main_app avoids the missing `attachment_path` error inside the engine.
    def lato_cms_attachment_path(attachment)
      main_app.rails_blob_path(attachment.blob, only_path: true)
    rescue StandardError
      '#'
    end

    def lato_cms_page_locale(page)
      content_tag(:span, class: 'badge bg-secondary') do
        concat locale_to_flag(page.locale)
        concat " #{page.locale.upcase}"
      end
    end

    def lato_cms_page_actions(page, show_edit: false, show_delete: false, hide_show: false)
      btn_group = capture do
        content_tag(:div, class: 'btn-group btn-group-sm') do
          concat(link_to(t('lato_cms.cta_show'), lato_cms.pages_show_path(page), class: 'btn btn-primary')) unless hide_show
          if show_edit
            concat link_to(t('lato_cms.cta_edit'), lato_cms.pages_update_path(page), class: 'btn btn-secondary',
              data: { lato_action_target: 'trigger', turbo_frame: dom_id(page, 'form'), action_title: t('lato_cms.page_update_title') })
          end
          if show_delete
            concat link_to(t('lato_cms.cta_delete'), lato_cms.pages_destroy_action_path(page), class: 'btn btn-danger',
              data: { turbo_method: 'DELETE', turbo_confirm: t('lato_cms.cta_delete_confirm') })
          end
        end
      end

      content_tag(:div, class: 'd-flex align-items-center gap-2') do
        if page.frontend_url.blank?
          concat content_tag(:span, t('lato_cms.action_view_frontend'), class: 'btn btn-sm btn-link px-0 disabled text-muted')
        else
          concat link_to(t('lato_cms.action_view_frontend'), page.frontend_url, class: 'btn btn-sm btn-link px-0', target: '_blank')
        end
        concat btn_group
      end
    end

    def lato_cms_render_field(field_id:, field_config:, page_field:, input_name_prefix: nil, dom_id_prefix: nil)
      render resolve_lato_cms_field_partial(field_config),
        field_id: field_id,
        field_config: field_config,
        page_field: page_field,
        input_name_prefix: input_name_prefix,
        dom_id_prefix: dom_id_prefix
    rescue ActionView::MissingTemplate => e
      content_tag(:div, class: 'alert alert-danger mb-0') do
        "Field '#{field_id}' render error: #{e.message}"
      end
    end

    def lato_cms_field_input_name(field_id, suffix = 'value', input_name_prefix: nil, multiple: false)
      base = input_name_prefix.presence || "fields[#{field_id}]"
      name = "#{base}[#{suffix}]"
      multiple ? "#{name}[]" : name
    end

    def lato_cms_field_dom_id(field_id, suffix = 'value', dom_id_prefix: nil)
      base = dom_id_prefix.presence || "fields_#{field_id}"
      "#{base}_#{suffix}".parameterize(separator: '_')
    end

    private

    def resolve_lato_cms_field_partial(field_config)
      type = (field_config['type'] || 'string').to_s
      return "lato_cms/pages/fields/#{type}" if BUILTIN_FIELD_TYPES.include?(type)
      return 'lato_cms/pages/fields/string' unless type == 'custom'

      render_path = field_config['render'].to_s.strip
      return 'lato_cms/pages/fields/string' if render_path.blank?

      render_path
    end
  end
end
