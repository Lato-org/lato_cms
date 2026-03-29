import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["iframe"]

  refresh() {
    if (!this.hasIframeTarget) return

    const iframe = this.iframeTarget
    if (iframe.src) {
      const url = new URL(iframe.src)
      url.searchParams.set('_t', Date.now())
      iframe.src = url.toString()
    }
  }
}
