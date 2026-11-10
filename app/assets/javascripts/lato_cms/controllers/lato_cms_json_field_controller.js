import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "status"]
  static values = { validLabel: String, invalidLabel: String }

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
      this.statusTarget.textContent = this.validLabelValue
      this.statusTarget.className = "form-text text-success"
    } catch (e) {
      this.statusTarget.textContent = this.invalidLabelValue.replace("%{error}", e.message)
      this.statusTarget.className = "form-text text-danger"
    }
  }
}
