module LatoCms
  module MediaHelper
    MEDIA_TYPE_ICONS = {
      'image' => 'bi-image',
      'video' => 'bi-film',
      'document' => 'bi-file-earmark-text',
      'file' => 'bi-paperclip'
    }.freeze

    # Index name cell: thumbnail (or type icon) + name + filename.
    def lato_cms_media_name(media)
      content_tag(:div, class: 'd-flex align-items-center gap-2') do
        concat lato_cms_media_thumb(media)
        concat(content_tag(:div) do
          concat content_tag(:div, media.name)
          concat content_tag(:span, media.filename, class: 'text-muted small')
        end)
      end
    end

    # Small thumbnail (image variant) or a type icon when there's no visual preview.
    def lato_cms_media_thumb(media, size: 40)
      if media.thumbnail_url
        image_tag media.thumbnail_url, class: 'rounded', style: "width: #{size}px; height: #{size}px; object-fit: cover;", alt: media.alt_text
      else
        content_tag(:div, class: 'd-flex align-items-center justify-content-center bg-light rounded text-muted',
          style: "width: #{size}px; height: #{size}px;") do
          content_tag(:i, '', class: "bi #{MEDIA_TYPE_ICONS[media.media_type] || 'bi-file-earmark'}")
        end
      end
    end

    # Index usages cell: how many page fields reference this media, so the
    # admin sees at a glance which files are actually in use (the detail is in
    # the edit form, which lists the pages).
    def lato_cms_media_usages(media)
      count = media.usage_count
      return content_tag(:span, t('lato_cms.media_usages_none'), class: 'text-muted small') if count.zero?

      content_tag(:span, t('lato_cms.media_usages_count', count: count), class: 'badge bg-info text-dark')
    end

    def lato_cms_media_media_type(media)
      content_tag(:span, media.media_type, class: 'badge bg-secondary')
    end

    # Index actions cell: detail page + edit metadata + delete (delete gated to
    # admins, same convention as pages). Delete is rendered inert while the
    # media is still referenced: the action would be refused server-side
    # anyway, so the button says why instead of failing after the fact.
    def lato_cms_media_actions(media)
      content_tag(:div, class: 'btn-group btn-group-sm') do
        concat link_to(t('lato_cms.cta_show'), lato_cms.media_show_path(media), class: 'btn btn-primary')
        concat link_to(t('lato_cms.cta_edit'), lato_cms.media_update_path(media), class: 'btn btn-secondary',
          data: { lato_action_target: 'trigger', turbo_frame: dom_id(media, 'form'), action_title: t('lato_cms.media_update_title') })
        concat lato_cms_media_delete_action(media) if lato_cms_admin?
      end
    end

    private

    def lato_cms_media_delete_action(media)
      usage_count = media.usage_count
      return link_to(t('lato_cms.cta_delete'), lato_cms.media_destroy_action_path(media), class: 'btn btn-danger',
        data: { turbo_method: 'DELETE', turbo_confirm: t('lato_cms.cta_delete_confirm') }) if usage_count.zero?

      content_tag(:span, t('lato_cms.cta_delete'), class: 'btn btn-danger disabled',
        title: t('lato_cms.media_delete_in_use', count: usage_count), data: { controller: 'lato-tooltip' })
    end
  end
end
