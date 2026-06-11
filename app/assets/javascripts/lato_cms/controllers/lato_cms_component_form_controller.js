import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitBtn", "status"]

  connect() {
    this.element.addEventListener("submit", this.handleSubmit.bind(this))
  }

  async handleSubmit(event) {
    event.preventDefault()

    const form = this.element
    const submitBtn = this.submitBtnTarget
    const originalHTML = submitBtn.innerHTML

    submitBtn.disabled = true
    submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>Saving...'

    try {
      const formData = new FormData(form)
      const response = await fetch(form.action, {
        method: 'POST',
        body: formData,
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        }
      })

      const data = await response.json()

      if (response.ok) {
        this.showStatus('Fields saved successfully', 'success')
        this.refreshPreview()
      } else {
        const errorMsg = data.errors?.map(e => `${e.field_id}: ${e.errors.join(', ')}`).join('; ') || 'Failed to save fields'
        this.showStatus(errorMsg, 'danger')
      }
    } catch (error) {
      this.showStatus('An error occurred while saving', 'danger')
    } finally {
      submitBtn.disabled = false
      submitBtn.innerHTML = originalHTML
    }
  }

  refreshPreview() {
    const iframe = document.querySelector('[data-lato-cms-page-preview-target="iframe"]')
    if (iframe && iframe.src) {
      const url = new URL(iframe.src)
      url.searchParams.set('_t', Date.now())
      iframe.src = url.toString()
    }
  }

  showStatus(message, type) {
    if (!this.hasStatusTarget) return

    clearTimeout(this._statusTimeout)

    const isSuccess = type === 'success'
    const icon = isSuccess ? 'bi-check-circle-fill' : 'bi-exclamation-circle-fill'
    const color = isSuccess ? 'text-success' : 'text-danger'

    this.statusTarget.innerHTML = `
      <span class="d-inline-flex align-items-center gap-1 small ${color} lato-cms-component-form__status">
        <i class="bi ${icon}"></i>${message}
      </span>`

    if (isSuccess) {
      this._statusTimeout = setTimeout(() => {
        const msg = this.statusTarget.querySelector('.lato-cms-component-form__status')
        if (msg) msg.classList.add('lato-cms-component-form__status--fade')
        setTimeout(() => { this.statusTarget.innerHTML = '' }, 400)
      }, 3000)
    }
  }
}
