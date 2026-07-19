import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "newPreview", "newPreviewContainer", "newPreviewName", "newPreviewSize", "currentContainer", "currentImage", "removedNotice"]

  connect() {
    this.afterSave = this.afterSave.bind(this)
    this.element.closest('form')?.addEventListener('lato-cms:fields-save-success', this.afterSave)
  }

  disconnect() {
    this.element.closest('form')?.removeEventListener('lato-cms:fields-save-success', this.afterSave)
  }

  preview() {
    const file = this.inputTarget.files[0]
    if (!file || !file.type.startsWith('image/')) return

    const reader = new FileReader()
    reader.onload = ({ target }) => {
      this.newPreviewTarget.src = target.result
      this.newPreviewTarget.alt = file.name
      this.newPreviewNameTarget.textContent = file.name
      this.newPreviewSizeTarget.textContent = `(${this.humanSize(file.size)})`
      this.newPreviewContainerTarget.classList.remove('d-none')
      this.undo()
      if (this.hasCurrentContainerTarget) this.currentContainerTarget.classList.add('d-none')
    }
    reader.readAsDataURL(file)
  }

  removeNew() {
    this.inputTarget.value = ''
    this.newPreviewTarget.src = ''
    this.newPreviewTarget.alt = ''
    this.newPreviewNameTarget.textContent = ''
    this.newPreviewSizeTarget.textContent = ''
    this.newPreviewContainerTarget.classList.add('d-none')
    if (this.hasCurrentContainerTarget) this.currentContainerTarget.classList.remove('d-none')
  }

  remove() {
    if (!this.hasCurrentContainerTarget) return

    this.currentContainerTarget.classList.add('lato-cms-file-field__item--removing')
    this.removedNoticeTarget.classList.remove('d-none')
    this.ensureRemoveInput()
    this.syncRequired()
  }

  undo() {
    if (!this.hasCurrentContainerTarget) return

    this.currentContainerTarget.classList.remove('lato-cms-file-field__item--removing')
    this.removedNoticeTarget.classList.add('d-none')
    this.removeInput?.remove()
    this.removeInput = null
    this.syncRequired()
  }

  // The file input only has to be required while no attachment survives the next
  // save: a persisted attachment (not marked for removal) already satisfies the
  // field, so keeping `required` on the emptied input would block every re-save.
  syncRequired() {
    const hasActiveAttachment = this.hasCurrentContainerTarget &&
      !this.currentContainerTarget.classList.contains('lato-cms-file-field__item--removing')
    this.inputTarget.required = this.fieldRequired && !hasActiveAttachment
  }

  ensureRemoveInput() {
    if (this.removeInput) return

    const input = document.createElement('input')
    input.type = 'hidden'
    input.name = this.inputTarget.name.replace(/\[files\]\[\]$/, '[remove_file_ids][]')
    input.value = this.currentContainerTarget.dataset.attachmentId
    this.element.appendChild(input)
    this.removeInput = input
  }

  afterSave(event) {
    if (!event.detail.success) return

    this.inputTarget.value = ''
    this.removeInput = null
    const field = this.findSavedField(event.detail.data?.fields || [])
    if (!field) return

    const attachment = field.attachments[0]
    this.element.querySelector('[data-lato-cms-image-field-target="currentContainer"]')?.remove()
    this.newPreviewContainerTarget.classList.add('d-none')

    if (attachment) {
      this.element.insertBefore(this.buildCurrentContainer(attachment), this.newPreviewContainerTarget)
    }
    this.syncRequired()
  }

  findSavedField(fields) {
    return fields.find(field => {
      return field.persisted_field_id === this.fieldId || field.field_id === this.fieldId
    })
  }

  buildCurrentContainer(attachment) {
    const container = document.createElement('div')
    container.className = 'lato-cms-file-field__item lato-cms-image-field__item'
    container.dataset.latoCmsImageFieldTarget = 'currentContainer'
    container.dataset.attachmentId = attachment.id
    container.innerHTML = `
      <div class="lato-cms-image-field__preview">
        <img src="${attachment.url}" class="lato-cms-image-field__thumb" data-lato-cms-image-field-target="currentImage" alt="${this.escapeHtml(attachment.filename)}">
      </div>
      <div class="lato-cms-file-field__info">
        <i class="bi bi-image"></i>
        <span>${this.escapeHtml(attachment.filename)}</span>
        <span class="text-muted small">(${this.humanSize(attachment.byte_size || 0)})</span>
      </div>
      <button type="button" class="lato-cms-attachment-field__remove" title="${this.removeLabel}" aria-label="${this.removeLabel}" data-action="lato-cms-image-field#remove">
        <i class="bi bi-trash"></i>
      </button>
      <div class="lato-cms-file-field__removed d-none" data-lato-cms-image-field-target="removedNotice">
        <span class="text-danger small">
          <i class="bi bi-trash me-1"></i>${this.removePendingLabel}
        </span>
        <button type="button" class="btn btn-link btn-sm p-0" data-action="lato-cms-image-field#undo">
          ${this.undoLabel}
        </button>
      </div>
    `
    return container
  }

  humanSize(size) {
    if (size < 1024) return `${size} B`
    if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`
    return `${(size / 1024 / 1024).toFixed(1)} MB`
  }

  escapeHtml(value) {
    return value.replace(/[&<>"']/g, char => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;'
    }[char]))
  }

  get fieldId() {
    return this.element.dataset.fieldId
  }

  get fieldRequired() {
    return this.element.dataset.fieldRequired === 'true'
  }

  get removeLabel() {
    return this.element.dataset.removeLabel || 'Remove'
  }

  get removePendingLabel() {
    return this.element.dataset.removePendingLabel || 'Image will be removed on save'
  }

  get undoLabel() {
    return this.element.dataset.undoLabel || 'Undo'
  }
}
