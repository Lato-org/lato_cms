import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "source", "input", "toolbar", "sourceBtn"]

  #sourceMode = false

  connect() {
    this.editorTarget.addEventListener("input", () => this.sync())
    this.sourceTarget.addEventListener("input", () => this.syncFromSource())

    // Prevent toolbar buttons from stealing focus (preserves text selection)
    this.toolbarTarget.querySelectorAll("button").forEach(btn => {
      btn.addEventListener("mousedown", (e) => e.preventDefault())
    })

    // Sync to hidden input just before form submission
    const form = this.element.closest("form")
    if (form) {
      form.addEventListener("submit", () => this.sync(), { capture: true })
    }
  }

  // ── Sync helpers ────────────────────────────────────────────────────────────

  sync() {
    this.inputTarget.value = this.editorTarget.innerHTML
  }

  syncFromSource() {
    this.inputTarget.value = this.sourceTarget.value
  }

  // ── Toggle source view ──────────────────────────────────────────────────────

  toggleSource() {
    this.#sourceMode = !this.#sourceMode

    if (this.#sourceMode) {
      // Copy current HTML into the textarea (pretty-printed)
      this.sourceTarget.value = this.editorTarget.innerHTML
      this.editorTarget.classList.add("d-none")
      this.sourceTarget.classList.remove("d-none")
      this.sourceTarget.style.height = this.editorTarget.offsetHeight + "px"
      this.sourceBtnTarget.classList.replace("btn-outline-secondary", "btn-secondary")
    } else {
      // Apply edited source back to the editor
      this.editorTarget.innerHTML = this.sourceTarget.value
      this.sync()
      this.sourceTarget.classList.add("d-none")
      this.editorTarget.classList.remove("d-none")
      this.sourceBtnTarget.classList.replace("btn-secondary", "btn-outline-secondary")
    }
  }

  // ── execCommand wrappers ────────────────────────────────────────────────────

  exec(command, value = null) {
    if (this.#sourceMode) return
    this.editorTarget.focus()
    document.execCommand(command, false, value)
    this.sync()
  }

  bold()                { this.exec("bold") }
  italic()              { this.exec("italic") }
  underline()           { this.exec("underline") }
  strikethrough()       { this.exec("strikeThrough") }
  alignLeft()           { this.exec("justifyLeft") }
  alignCenter()         { this.exec("justifyCenter") }
  alignRight()          { this.exec("justifyRight") }
  insertUnorderedList() { this.exec("insertUnorderedList") }
  insertOrderedList()   { this.exec("insertOrderedList") }
}
