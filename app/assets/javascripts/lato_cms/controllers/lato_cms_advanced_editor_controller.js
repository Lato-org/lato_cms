import { Controller } from "@hotwired/stimulus"

const COMPONENT_FORM = 'form[data-controller~="lato-cms-component-form"]'

export default class extends Controller {
  static targets = ["editorCol", "reopenBtn"]
  static values = { listPath: String, unsavedMessage: String }

  isSidebarOpen = true

  // ─── Advanced full-screen editor is the only view ────────────────────────────
  // The full-screen layout is rendered server-side (--active class + body CSS) so
  // it survives re-renders (e.g. component clone) with no flash. JS wires up
  // Escape-to-back, the unsaved-changes guard and the sidebar toggle.

  connect() {
    // Each component is its own form: the ones edited since their last save.
    this.dirtyForms = new Set()

    this._escHandler = (e) => this.onKeydown(e)
    this._changeHandler = (e) => this.markDirty(e)
    this._savedHandler = (e) => this.dirtyForms.delete(e.target.closest(COMPONENT_FORM))
    this._beforeUnloadHandler = (e) => {
      if (!this.hasUnsavedChanges()) return
      e.preventDefault()
      e.returnValue = ''
    }
    this._beforeVisitHandler = (e) => {
      if (this.hasUnsavedChanges() && !window.confirm(this.unsavedMessageValue)) e.preventDefault()
    }

    document.addEventListener('keydown', this._escHandler)
    this.element.addEventListener('input', this._changeHandler)
    this.element.addEventListener('change', this._changeHandler)
    this.element.addEventListener('lato-cms:fields-save-success', this._savedHandler)
    window.addEventListener('beforeunload', this._beforeUnloadHandler)
    document.addEventListener('turbo:before-visit', this._beforeVisitHandler)
  }

  disconnect() {
    document.removeEventListener('keydown', this._escHandler)
    this.element.removeEventListener('input', this._changeHandler)
    this.element.removeEventListener('change', this._changeHandler)
    this.element.removeEventListener('lato-cms:fields-save-success', this._savedHandler)
    window.removeEventListener('beforeunload', this._beforeUnloadHandler)
    document.removeEventListener('turbo:before-visit', this._beforeVisitHandler)
  }

  markDirty(event) {
    const form = event.target.closest?.(COMPONENT_FORM)
    if (form) this.dirtyForms.add(form)
  }

  hasUnsavedChanges() {
    return this.dirtyForms.size > 0
  }

  // Escape goes back to the list only when nothing else owns the key: an
  // open modal, dropdown or tooltip closes itself on Escape, and Escape while
  // typing must not navigate away.
  onKeydown(e) {
    if (e.key !== 'Escape' || e.defaultPrevented) return
    if (document.querySelector('.modal.show, .dropdown-menu.show')) return

    const active = document.activeElement
    if (active && (active.isContentEditable || active.matches('input, textarea, select'))) return

    this.back()
  }

  back() {
    if (!this.hasListPathValue) return
    if (this.hasUnsavedChanges() && !window.confirm(this.unsavedMessageValue)) return

    // Already confirmed: skip the beforeunload prompt.
    this.dirtyForms.clear()
    window.location.href = this.listPathValue
  }

  // ─── Toggle sidebar within advanced mode ─────────────────────────────────────

  toggleSidebar() {
    this.isSidebarOpen = !this.isSidebarOpen
    this.editorColTarget.classList.toggle('lato-cms-advanced-editor__editor-col--collapsed', !this.isSidebarOpen)
    this.reopenBtnTarget.hidden = this.isSidebarOpen
  }
}
