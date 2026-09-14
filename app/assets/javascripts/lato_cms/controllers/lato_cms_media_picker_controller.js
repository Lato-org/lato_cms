import { Controller } from '@hotwired/stimulus'

// Modal content loaded via the `lato-action` mechanism (see lato_action_controller.js).
// Lets the admin browse the Media library or upload a new file, then writes
// the selection back to whichever field opened this picker by dispatching a
// `lato-cms:media-selected` event on `document`, correlated by the picker's
// own turbo-frame id (unique per field instance, even inside a repeater).
export default class extends Controller {
  static targets = ['grid', 'item', 'selectedCount', 'confirmButton', 'uploadNotice']
  static values = { multiple: Boolean, selectedLabel: String }

  connect () {
    this.frameId = this.element.closest('turbo-frame')?.id
    this.pending = new Map()
  }

  select (event) {
    const item = this.buildItemFromElement(event.currentTarget)

    if (!this.multipleValue) {
      this.dispatchSelection([item])
      this.closeModal()
      return
    }

    if (this.pending.has(item.id)) {
      this.pending.delete(item.id)
      event.currentTarget.classList.remove('lato-cms-media-picker__item--selected')
    } else {
      this.pending.set(item.id, item)
      event.currentTarget.classList.add('lato-cms-media-picker__item--selected')
    }

    this.updateSelectionUi()
  }

  confirm () {
    if (this.pending.size === 0) return

    this.dispatchSelection(Array.from(this.pending.values()))
    this.closeModal()
  }

  // Result of the XHR upload driven by `lato-cms-upload` (which owns the
  // request and its progress bar); this only turns the created media into a
  // selection.
  uploadCompleted (event) {
    const data = event.detail
    const item = {
      id: data.id,
      name: data.name,
      thumbnailUrl: data.thumbnail_url,
      mediaType: data.media_type,
      url: data.url,
      posterUrl: data.poster_url
    }

    if (!this.multipleValue) {
      this.dispatchSelection([item])
      this.closeModal()
      return
    }

    this.pending.set(item.id, item)
    this.updateSelectionUi()
    this.uploadNoticeTarget.innerHTML = `<div class="alert alert-success">${item.name}</div>`
  }

  uploadFailed (event) {
    this.uploadNoticeTarget.innerHTML = `<div class="alert alert-danger">${event.detail.message}</div>`
  }

  buildItemFromElement (element) {
    return {
      id: element.dataset.mediaId,
      name: element.dataset.mediaName,
      thumbnailUrl: element.dataset.mediaThumb,
      mediaType: element.dataset.mediaType,
      url: element.dataset.mediaUrl,
      posterUrl: element.dataset.mediaPosterUrl
    }
  }

  dispatchSelection (items) {
    document.dispatchEvent(new CustomEvent('lato-cms:media-selected', {
      bubbles: true,
      detail: { frameId: this.frameId, items }
    }))
  }

  updateSelectionUi () {
    if (this.hasSelectedCountTarget) this.selectedCountTarget.textContent = `${this.pending.size} ${this.selectedLabelValue}`
    if (this.hasConfirmButtonTarget) this.confirmButtonTarget.disabled = this.pending.size === 0
  }

  closeModal () {
    const modalElement = this.element.closest('.modal')
    if (!modalElement) return

    window.bootstrap.Modal.getInstance(modalElement)?.hide()
  }
}
