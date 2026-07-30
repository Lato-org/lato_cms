import { Controller } from '@hotwired/stimulus'

// Generic controller for image/video/file/gallery fields backed by the Media
// library (replaces the old per-type native-upload controllers). Holds the
// selected media id(s) in hidden input(s) and renders a preview; the actual
// picking happens in a modal driven by lato_cms_media_picker_controller.js,
// which writes the selection back here via a `lato-cms:media-selected`
// event correlated by this field's own turbo-frame id.
export default class extends Controller {
  static targets = ['grid', 'addTile', 'validationAnchor']
  static values = { kind: String, multiple: Boolean, frameId: String, hiddenName: String, fieldId: String }

  connect () {
    this.onMediaSelected = this.onMediaSelected.bind(this)
    this.afterSave = this.afterSave.bind(this)

    document.addEventListener('lato-cms:media-selected', this.onMediaSelected)
    this.form = this.element.closest('form')
    this.form?.addEventListener('lato-cms:fields-save-success', this.afterSave)
  }

  disconnect () {
    document.removeEventListener('lato-cms:media-selected', this.onMediaSelected)
    this.form?.removeEventListener('lato-cms:fields-save-success', this.afterSave)
  }

  // Opens the picker in an overlay. Reuses the same pool of pre-rendered
  // Bootstrap modals the shared `lato-action` mechanism uses, but drives it
  // directly instead of going through that controller's trigger convention:
  // that convention opens a frame by hoping Turbo notices it was just
  // inserted before driving a full-page visit off the link's plain href,
  // and loses that race for this link (verified: it was navigating to a
  // separate page instead of showing an overlay). Setting the frame's `src`
  // explicitly is Turbo's documented, non-racy way to trigger a frame fetch.
  openPicker (event) {
    event.preventDefault()

    const link = event.currentTarget
    const modal = Array.from(document.querySelectorAll('[data-lato-action-target="modal"]'))
      .find(el => !el.classList.contains('show'))
    if (!modal) return

    const body = modal.querySelector('[data-lato-action-target="modalBody"]')
    const title = modal.querySelector('[data-lato-action-target="modalTitle"]')
    const dialog = modal.querySelector('[data-lato-action-target="modalDialog"]')

    body.innerHTML = `
      <turbo-frame id="${this.frameIdValue}">
        <div class="placeholder-glow"><span class="placeholder placeholder-lg col-12"></span></div>
      </turbo-frame>`
    title.textContent = link.dataset.actionTitle || ''
    dialog.classList.remove('modal-sm', 'modal-md', 'modal-lg', 'modal-xl')
    dialog.classList.add(`modal-${link.dataset.actionSize || 'md'}`)

    window.bootstrap.Modal.getOrCreateInstance(modal).show()
    body.querySelector('turbo-frame').src = link.href
  }

  onMediaSelected (event) {
    if (event.detail.frameId !== this.frameIdValue) return

    if (!this.multipleValue) {
      this.itemTiles().forEach(tile => tile.remove())
    }
    event.detail.items.forEach(item => this.appendItem(item))

    this.syncEmptyAndValidation()
  }

  remove (event) {
    event.currentTarget.closest('.lato-cms-media-field__item')?.remove()
    this.syncEmptyAndValidation()
  }

  afterSave (event) {
    if (!event.detail.success) return

    const field = (event.detail.data?.fields || []).find(
      f => f.persisted_field_id === this.fieldIdValue || f.field_id === this.fieldIdValue
    )
    if (!field) return

    this.itemTiles().forEach(tile => tile.remove())
    field.attachments.forEach(attachment => this.appendItem({
      id: attachment.media_id,
      name: attachment.name,
      thumbnailUrl: attachment.url,
      url: attachment.url,
      posterUrl: attachment.poster_url
    }))
    this.syncEmptyAndValidation()
  }

  appendItem (item) {
    if (!item || this.gridTarget.querySelector(`[data-media-id="${item.id}"]`)) return

    const wide = !this.multipleValue && ['image', 'video'].includes(this.kindValue)

    const wrapper = document.createElement('div')
    wrapper.className = `lato-cms-media-field__tile lato-cms-media-field__item${wide ? ' lato-cms-media-field__tile--wide' : ''}`
    wrapper.dataset.mediaId = item.id
    if (this.multipleValue) {
      wrapper.draggable = true
      wrapper.dataset.action = 'dragstart->lato-cms-media-reorder#onDragStart dragend->lato-cms-media-reorder#onDragEnd'
      wrapper.setAttribute('data-lato-cms-media-reorder-target', 'item')
    }

    wrapper.innerHTML = `
      ${this.previewMarkup(item)}
      <div class="lato-cms-media-field__overlay">
        <span class="lato-cms-media-field__name">${item.name}</span>
      </div>
      <button type="button" class="lato-cms-media-field__remove" data-action="lato-cms-media-field#remove">
        <i class="bi bi-x-lg"></i>
      </button>
      <input type="hidden" name="${this.hiddenNameValue}" value="${item.id}">`

    this.gridTarget.insertBefore(wrapper, this.addTileTarget)
  }

  previewMarkup (item) {
    if (this.kindValue === 'video') {
      return `<video controls preload="metadata" class="lato-cms-media-field__player" src="${item.url}"></video>`
    }
    if (item.thumbnailUrl || item.url) {
      return `<img src="${item.thumbnailUrl || item.url}" class="lato-cms-media-field__thumb">`
    }
    return '<div class="lato-cms-media-field__icon"><i class="bi bi-paperclip"></i></div>'
  }

  itemTiles () {
    return Array.from(this.gridTarget.querySelectorAll('.lato-cms-media-field__item'))
  }

  syncEmptyAndValidation () {
    const hasItems = this.itemTiles().length > 0

    if (!this.multipleValue) this.addTileTarget.classList.toggle('d-none', hasItems)
    if (this.hasValidationAnchorTarget) {
      this.validationAnchorTarget.value = hasItems ? '1' : ''
      this.validationAnchorTarget.required = this.element.dataset.fieldRequired === 'true' && !hasItems
    }
  }
}
