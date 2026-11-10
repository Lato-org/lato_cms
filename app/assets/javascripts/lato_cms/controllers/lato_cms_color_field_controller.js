import { Controller } from "@hotwired/stimulus"

// The hidden `value` target is what the form submits; the native color input
// is only the picker, since it can never be empty.
export default class extends Controller {
  static targets = ["input", "value", "hex"]
  static values = { emptyLabel: String }

  update() {
    this.valueTarget.value = this.inputTarget.value
    this.hexTarget.textContent = this.inputTarget.value.toUpperCase()
  }

  clear() {
    this.valueTarget.value = ""
    this.hexTarget.textContent = this.emptyLabelValue
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
