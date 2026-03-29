module LatoCms
  module PagesHelper
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
  end
end
