import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "source", "input", "toolbar", "sourceBtn"]
  static values = { tags: String, attributes: String }

  #sourceMode = false

  connect() {
    this.editorTarget.addEventListener("input", () => this.sync())
    this.sourceTarget.addEventListener("input", () => this.syncFromSource())
    this.editorTarget.addEventListener("paste", event => {
      event.preventDefault()
      const html = event.clipboardData.getData("text/html")
      document.execCommand(html ? "insertHTML" : "insertText", false,
        html ? this.sanitize(html) : event.clipboardData.getData("text/plain"))
      this.sync()
    })
    this.editorTarget.addEventListener("drop", event => event.preventDefault())

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
    if (this.#sourceMode) return this.syncFromSource()
    this.inputTarget.value = this.editorTarget.innerHTML
  }

  syncFromSource() {
    this.inputTarget.value = this.sanitize(this.sourceTarget.value)
  }

  sanitize(html) {
    // Template contents stay inert while source HTML is reduced to the server's allowlist.
    const template = document.createElement("template")
    template.innerHTML = html
    const tags = new Set(this.tagsValue.split(" "))
    const attributes = new Set(this.attributesValue.split(" "))
    template.content.querySelectorAll("*").forEach(element => {
      if (!tags.has(element.localName)) {
        if (["script", "style", "iframe", "object", "embed", "svg", "math", "template"].includes(element.localName)) {
          element.remove()
        } else {
          element.replaceWith(...element.childNodes)
        }
        return
      }
      Array.from(element.attributes).forEach(attribute => {
        if (!attributes.has(attribute.name)) {
          element.removeAttribute(attribute.name)
        } else if (["href", "src"].includes(attribute.name)) {
          try {
            const url = new URL(attribute.value, document.baseURI)
            if (!["http:", "https:", "mailto:", "tel:"].includes(url.protocol)) element.removeAttribute(attribute.name)
          } catch {
            element.removeAttribute(attribute.name)
          }
        } else if (attribute.name === "style") {
          const alignment = element.style.textAlign
          element.removeAttribute("style")
          if (["left", "center", "right", "justify"].includes(alignment)) element.style.textAlign = alignment
        }
      })
    })
    return template.innerHTML
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
      this.editorTarget.innerHTML = this.sanitize(this.sourceTarget.value)
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
