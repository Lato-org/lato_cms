import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "newPreview", "newPreviewContainer", "currentContainer", "currentImage", "removeCheck"]

  preview() {
    const file = this.inputTarget.files[0]
    if (!file || !file.type.startsWith('image/')) return

    const reader = new FileReader()
    reader.onload = ({ target }) => {
      this.newPreviewTarget.src = target.result
      this.newPreviewContainerTarget.classList.remove('d-none')
    }
    reader.readAsDataURL(file)
  }

  toggleRemove() {
    if (!this.hasCurrentImageTarget) return
    const removing = this.removeCheckTarget.checked
    this.currentImageTarget.style.opacity = removing ? '0.3' : ''
    this.currentImageTarget.style.outline = removing ? '2px solid var(--bs-danger)' : ''
  }
}
