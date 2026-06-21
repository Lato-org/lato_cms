import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item", "list", "removedNotice"]
  static values = { multiple: Boolean }

  newFileMap = new Map()
  nextUid = 0

  connect() {
    this.afterSave = this.afterSave.bind(this)
    this.element.closest('form')?.addEventListener('lato-cms:fields-save-success', this.afterSave)
  }

  disconnect() {
    this.element.closest('form')?.removeEventListener('lato-cms:fields-save-success', this.afterSave)
  }

  addFiles() {
    if (!this.multipleValue) this.prepareSingleReplacement()

    Array.from(this.inputTarget.files).forEach(file => {
      const uid = `new_${this.nextUid++}`
      this.newFileMap.set(uid, file)
      this.listTarget.appendChild(this.buildNewItem(file, uid))
    })

    this.inputTarget.value = ''
    this.syncFileInput()
  }

  remove(event) {
    const item = event.currentTarget.closest('[data-lato-cms-file-field-target="item"]')
    if (!item) return

    if (item.dataset.fileUid) {
      this.newFileMap.delete(item.dataset.fileUid)
      item.remove()
      this.syncFileInput()
      if (!this.multipleValue) this.restoreReplacedItems()
      return
    }

    item.classList.add('lato-cms-file-field__item--removing')
    item.querySelector('[data-lato-cms-file-field-target="removedNotice"]')?.classList.remove('d-none')
    this.ensureRemoveInput(item)
  }

  undo(event) {
    const item = event.currentTarget.closest('[data-lato-cms-file-field-target="item"]')
    if (!item) return

    item.classList.remove('lato-cms-file-field__item--removing')
    item.querySelector('[data-lato-cms-file-field-target="removedNotice"]')?.classList.add('d-none')
    item.querySelector('[data-remove-file-input]')?.remove()
  }

  ensureRemoveInput(item) {
    if (item.querySelector('[data-remove-file-input]')) return

    const input = document.createElement('input')
    input.type = 'hidden'
    input.name = this.inputTarget.name.replace(/\[files\]\[\]$/, '[remove_file_ids][]')
    input.value = item.dataset.attachmentId
    input.setAttribute('data-remove-file-input', '')
    item.appendChild(input)
  }

  syncFileInput() {
    const dt = new DataTransfer()
    this.newFileMap.forEach(file => dt.items.add(file))
    this.inputTarget.files = dt.files
  }

  prepareSingleReplacement() {
    this.newFileMap.clear()
    this.listTarget.querySelectorAll('[data-file-uid]').forEach(item => item.remove())
    this.itemTargets
      .filter(item => item.dataset.attachmentId && !item.querySelector('[data-remove-file-input]'))
      .forEach(item => {
        item.classList.add('d-none')
        item.dataset.replacedByNewFile = 'true'
      })
  }

  restoreReplacedItems() {
    if (this.newFileMap.size > 0) return

    this.itemTargets
      .filter(item => item.dataset.replacedByNewFile === 'true')
      .forEach(item => {
        item.classList.remove('d-none')
        delete item.dataset.replacedByNewFile
      })
  }

  buildNewItem(file, uid) {
    const item = document.createElement('div')
    item.className = 'lato-cms-file-field__item lato-cms-file-field__item--new'
    item.dataset.latoCmsFileFieldTarget = 'item'
    item.dataset.fileUid = uid
    item.innerHTML = `
      <div class="lato-cms-file-field__info">
        <i class="bi bi-paperclip"></i>
        <span>${this.escapeHtml(file.name)}</span>
        <span class="text-muted small">(${this.humanSize(file.size)})</span>
        <span class="badge bg-success">${this.newBadgeLabel}</span>
      </div>
      <button type="button" class="btn btn-sm btn-outline-danger" data-action="lato-cms-file-field#remove">
        <i class="bi bi-trash me-1"></i>${this.removeLabel}
      </button>
    `
    return item
  }

  afterSave(event) {
    if (!event.detail.success) return

    this.newFileMap.clear()
    this.inputTarget.value = ''

    const field = this.findSavedField(event.detail.data?.fields || [])
    if (!field) {
      this.itemTargets
        .filter(item => item.querySelector('[data-remove-file-input]'))
        .forEach(item => item.remove())
      return
    }

    this.listTarget.innerHTML = ''
    field.attachments.forEach(attachment => {
      this.listTarget.appendChild(this.buildExistingItem(attachment))
    })
  }

  findSavedField(fields) {
    return fields.find(field => {
      return field.persisted_field_id === this.fieldId || field.field_id === this.fieldId
    })
  }

  buildExistingItem(attachment) {
    const item = document.createElement('div')
    item.className = 'lato-cms-file-field__item'
    item.dataset.latoCmsFileFieldTarget = 'item'
    item.dataset.attachmentId = attachment.id
    item.innerHTML = `
      <div class="lato-cms-file-field__info">
        <i class="bi bi-paperclip"></i>
        <span>${this.escapeHtml(attachment.filename)}</span>
        <span class="text-muted small">(${this.humanSize(attachment.byte_size || 0)})</span>
      </div>
      <button type="button" class="btn btn-sm btn-outline-danger" data-action="lato-cms-file-field#remove">
        <i class="bi bi-trash me-1"></i>${this.removeLabel}
      </button>
      <div class="lato-cms-file-field__removed d-none" data-lato-cms-file-field-target="removedNotice">
        <span class="text-danger small">
          <i class="bi bi-trash me-1"></i>${this.removePendingLabel}
        </span>
        <button type="button" class="btn btn-link btn-sm p-0" data-action="lato-cms-file-field#undo">
          ${this.undoLabel}
        </button>
      </div>
    `
    return item
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

  get newBadgeLabel() {
    return this.element.dataset.newBadgeLabel || 'New'
  }

  get removeLabel() {
    return this.element.dataset.removeLabel || 'Remove'
  }

  get removePendingLabel() {
    return this.element.dataset.removePendingLabel || 'File will be removed on save'
  }

  get undoLabel() {
    return this.element.dataset.undoLabel || 'Undo'
  }

  get fieldId() {
    return this.element.dataset.fieldId
  }
}
