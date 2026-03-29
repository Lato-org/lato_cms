import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["grid", "fileInput", "emptyMsg"]
  static values = { fieldId: String }

  dragging = null
  newFileMap = new Map()
  nextUid = 0

  // ─── File selection ─────────────────────────────────────────────────────────

  addFiles() {
    Array.from(this.fileInputTarget.files).forEach(file => {
      if (!file.type.startsWith('image/')) return
      const uid = `new_${this.nextUid++}`
      this.newFileMap.set(uid, file)

      const reader = new FileReader()
      reader.onload = ({ target }) => {
        const item = this.buildItem(target.result, null, uid)
        this.gridTarget.appendChild(item)
        this.updateEmpty()
        this.updateOrderInputs()
      }
      reader.readAsDataURL(file)
    })

    // Reset input then sync with DataTransfer
    this.fileInputTarget.value = ''
    this.syncFileInput()
  }

  // ─── Remove ─────────────────────────────────────────────────────────────────

  remove(event) {
    const item = event.currentTarget.closest('[data-gallery-item]')
    if (!item) return

    const { attachmentId, fileUid } = item.dataset

    if (attachmentId) {
      const input = document.createElement('input')
      input.type = 'hidden'
      input.name = `fields[${this.fieldIdValue}][remove_file_ids][]`
      input.value = attachmentId
      this.element.appendChild(input)
    } else if (fileUid) {
      this.newFileMap.delete(fileUid)
      this.syncFileInput()
    }

    item.remove()
    this.updateEmpty()
    this.updateOrderInputs()
  }

  // ─── Drag & drop ─────────────────────────────────────────────────────────────

  onDragStart(event) {
    this.dragging = event.currentTarget
    event.dataTransfer.effectAllowed = 'move'
    // Defer class so browser can snapshot the element first
    requestAnimationFrame(() => event.currentTarget.classList.add('lato-cms-gallery-field__item--dragging'))
  }

  onDragEnd(event) {
    event.currentTarget.classList.remove('lato-cms-gallery-field__item--dragging')
    this.dragging = null
    this.updateOrderInputs()
  }

  onGridDragOver(event) {
    event.preventDefault()
    if (!this.dragging) return

    const target = event.target.closest('[data-gallery-item]')
    if (!target || target === this.dragging) return

    const { left, width } = target.getBoundingClientRect()
    const insertBefore = event.clientX < left + width / 2
    this.gridTarget.insertBefore(this.dragging, insertBefore ? target : target.nextSibling)
  }

  onGridDrop(event) {
    event.preventDefault()
  }

  // ─── Order inputs ────────────────────────────────────────────────────────────

  updateOrderInputs() {
    this.element.querySelectorAll('[data-gallery-order-input]').forEach(el => el.remove())

    this.gridTarget.querySelectorAll('[data-gallery-item][data-attachment-id]').forEach(item => {
      const id = item.dataset.attachmentId
      if (!id) return
      const input = document.createElement('input')
      input.type = 'hidden'
      input.name = `fields[${this.fieldIdValue}][order][]`
      input.value = id
      input.setAttribute('data-gallery-order-input', '')
      this.element.appendChild(input)
    })
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  syncFileInput() {
    const dt = new DataTransfer()
    this.newFileMap.forEach(file => dt.items.add(file))
    this.fileInputTarget.files = dt.files
  }

  updateEmpty() {
    if (!this.hasEmptyMsgTarget) return
    const hasItems = this.gridTarget.querySelector('[data-gallery-item]')
    this.emptyMsgTarget.classList.toggle('d-none', !!hasItems)
  }

  buildItem(src, attachmentId, fileUid) {
    const div = document.createElement('div')
    div.setAttribute('data-gallery-item', '')
    div.dataset.attachmentId = attachmentId || ''
    div.dataset.fileUid = fileUid || ''
    div.draggable = true
    div.className = 'lato-cms-gallery-field__item'
    div.setAttribute('data-action', 'dragstart->gallery-field#onDragStart dragend->gallery-field#onDragEnd')
    div.innerHTML = `
      <img src="${src}" class="lato-cms-gallery-field__thumb" alt="">
      <button type="button" class="lato-cms-gallery-field__remove" data-action="click->lato-cms-gallery-field#remove">
        <i class="bi bi-x-lg"></i>
      </button>
    `
    return div
  }
}
