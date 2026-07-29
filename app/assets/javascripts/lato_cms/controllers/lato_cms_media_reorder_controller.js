import { Controller } from '@hotwired/stimulus'

// Drag-and-drop reordering for multi-value media fields (gallery, file
// multiple). Mounted alongside lato_cms_media_field_controller on the same
// element. Submitted order comes from plain DOM order of the hidden inputs
// inside the grid, so reordering nodes here is the entire contract — no
// separate "order" param to keep in sync.
export default class extends Controller {
  static targets = ['grid', 'item']

  onDragStart (event) {
    this.dragging = event.currentTarget
    this.dragging.classList.add('lato-cms-media-field__item--dragging')
    event.dataTransfer.effectAllowed = 'move'
  }

  onDragEnd (event) {
    event.currentTarget.classList.remove('lato-cms-media-field__item--dragging')
    this.dragging = null
  }

  onGridDragOver (event) {
    event.preventDefault()
    if (!this.dragging) return

    const target = event.target.closest('.lato-cms-media-field__item')
    if (!target || target === this.dragging) return

    const rect = target.getBoundingClientRect()
    const before = (event.clientX - rect.left) < rect.width / 2
    this.gridTarget.insertBefore(this.dragging, before ? target : target.nextSibling)
  }

  onGridDrop (event) {
    event.preventDefault()
  }
}
