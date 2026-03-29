import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "status"]

  connect() {
    this.validate()
  }

  validate() {
    const value = this.inputTarget.value.trim()
    if (!value) {
      this.statusTarget.textContent = ""
      this.statusTarget.className = "form-text"
      return
    }

    try {
      JSON.parse(value)
      this.statusTarget.textContent = "Valid JSON"
      this.statusTarget.className = "form-text text-success"
    } catch (e) {
      this.statusTarget.textContent = "Invalid JSON: " + e.message
      this.statusTarget.className = "form-text text-danger"
    }
  }
}
