import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editorCol", "reopenBtn"]
  static values = { listPath: String }

  isSidebarOpen = true

  // ─── Advanced full-screen editor is the only view ────────────────────────────
  // The full-screen layout is rendered server-side (--active class + body CSS) so
  // it survives re-renders (e.g. component clone) with no flash. JS only wires up
  // Escape-to-back and the sidebar toggle.

  connect() {
    // Escape returns to the pages list instead of exiting to a base view.
    this._escHandler = (e) => { if (e.key === 'Escape') this.back() }
    document.addEventListener('keydown', this._escHandler)
  }

  disconnect() {
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
