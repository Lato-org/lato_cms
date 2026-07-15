import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "editorCol", "reopenBtn"]
  static values = { listPath: String }

  isSidebarOpen = true

  // ─── Advanced full-screen editor is the only view ────────────────────────────

  // Activate on load: no base view exists, only back to the pages list.
  connect() {
    this.rowTarget.classList.add('lato-cms-advanced-editor__row--active')
    document.body.classList.add('lato-cms-advanced-editor--open')

    // Escape returns to the pages list instead of exiting to a base view.
    this._escHandler = (e) => { if (e.key === 'Escape') this.back() }
    document.addEventListener('keydown', this._escHandler)
  }

  disconnect() {
    document.body.classList.remove('lato-cms-advanced-editor--open')
    document.removeEventListener('keydown', this._escHandler)
  }

  back() {
    if (this.hasListPathValue) window.location.href = this.listPathValue
  }

  // ─── Toggle sidebar within advanced mode ─────────────────────────────────────

  toggleSidebar() {
    this.isSidebarOpen = !this.isSidebarOpen
    this.editorColTarget.classList.toggle('lato-cms-advanced-editor__editor-col--collapsed', !this.isSidebarOpen)
    this.reopenBtnTarget.hidden = this.isSidebarOpen
  }
}
