import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hex"]

  update() {
    this.hexTarget.textContent = this.inputTarget.value.toUpperCase()
  }
}
