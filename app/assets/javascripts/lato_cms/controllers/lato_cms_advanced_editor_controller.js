import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "previewCol", "editorCol", "toggleBtn", "collapseBtn", "reopenBtn"]

  isActive = false
  isSidebarOpen = true

  // ─── Toggle advanced mode ────────────────────────────────────────────────────

  toggle() {
    this.isActive ? this.deactivate() : this.activate()
  }

  activate() {
    this.isActive = true
    this.isSidebarOpen = true

    this.rowTarget.classList.add('lato-cms-advanced-editor__row--active')
    document.body.classList.add('lato-cms-advanced-editor--open')

    this.toggleBtnTarget.title = 'Exit advanced editor'
    this.toggleBtnTarget.querySelector('i').className = 'bi bi-fullscreen-exit'
    this.collapseBtnTarget.classList.remove('d-none')
    this.editorColTarget.classList.remove('lato-cms-advanced-editor__editor-col--collapsed')
    this.reopenBtnTarget.hidden = true

    this._escHandler = (e) => { if (e.key === 'Escape') this.deactivate() }
    document.addEventListener('keydown', this._escHandler)
  }

  deactivate() {
    this.isActive = false
    this.isSidebarOpen = true

    this.rowTarget.classList.remove('lato-cms-advanced-editor__row--active')
    document.body.classList.remove('lato-cms-advanced-editor--open')

    this.toggleBtnTarget.title = 'Advanced editor'
    this.toggleBtnTarget.querySelector('i').className = 'bi bi-fullscreen'
    this.collapseBtnTarget.classList.add('d-none')
    this.editorColTarget.classList.remove('lato-cms-advanced-editor__editor-col--collapsed')
    this.reopenBtnTarget.hidden = true

    document.removeEventListener('keydown', this._escHandler)
  }

  // ─── Toggle sidebar within advanced mode ─────────────────────────────────────

  toggleSidebar() {
    if (!this.isActive) return

    this.isSidebarOpen = !this.isSidebarOpen
    this.editorColTarget.classList.toggle('lato-cms-advanced-editor__editor-col--collapsed', !this.isSidebarOpen)
    this.reopenBtnTarget.hidden = this.isSidebarOpen
  }
}
