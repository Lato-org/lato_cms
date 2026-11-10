import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitBtn", "status"]
  static values = { savingLabel: String, savedLabel: String, failedLabel: String, errorLabel: String }

  connect() {
    this.element.addEventListener("submit", this.handleSubmit.bind(this))
  }

  async handleSubmit(event) {
    event.preventDefault()

    const form = this.element
    const submitBtn = this.submitBtnTarget
    const originalHTML = submitBtn.innerHTML

    submitBtn.disabled = true
    submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-1" aria-hidden="true"></span>'
    submitBtn.append(document.createTextNode(this.savingLabelValue))
    this.clearFieldErrors()

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
        this.showStatus(data.message || this.savedLabelValue, 'success')
        form.dispatchEvent(new CustomEvent('lato-cms:fields-save-success', {
          bubbles: true,
          detail: { success: true, data }
        }))
        this.refreshPreview()
      } else {
        const errors = data.errors || []
        const errorMsg = errors.map(e => `${e.field_name || e.field_id}: ${e.errors.join(', ')}`).join('; ') || data.error || this.failedLabelValue
        this.showStatus(errorMsg, 'danger')
        this.showFieldErrors(errors)
      }
    } catch (error) {
      this.showStatus(this.errorLabelValue, 'danger')
    } finally {
      submitBtn.disabled = false
      submitBtn.innerHTML = originalHTML
    }
  }

  // Marks each failing field (its wrapper carries the persisted field id)
  // invalid, links the message to its inputs via aria-describedby and moves
  // focus to the first one, so the error is not only a line at the bottom.
  showFieldErrors(errors) {
    const wrappers = Array.from(this.element.querySelectorAll('[data-lato-cms-persisted-field-id]'))
    let firstInput = null

    errors.forEach((error, index) => {
      const wrapper = wrappers.find(element => element.dataset.latoCmsPersistedFieldId === error.field_id)
      if (!wrapper) return

      const feedback = document.createElement('div')
      feedback.id = `lato-cms-field-error-${Date.now()}-${index}`
      feedback.className = 'invalid-feedback d-block lato-cms-field-error'
      feedback.textContent = error.errors.join(', ')
      wrapper.append(feedback)

      wrapper.querySelectorAll('input:not([type="hidden"]), select, textarea, [contenteditable="true"]').forEach(input => {
        input.classList.add('is-invalid')
        input.setAttribute('aria-invalid', 'true')
        input.setAttribute('aria-describedby', feedback.id)
        firstInput ||= input
      })
    })

    firstInput?.focus()
  }

  clearFieldErrors() {
    this.element.querySelectorAll('.lato-cms-field-error').forEach(element => element.remove())
    this.element.querySelectorAll('[aria-invalid="true"]').forEach(input => {
      input.classList.remove('is-invalid')
      input.removeAttribute('aria-invalid')
      input.removeAttribute('aria-describedby')
    })
  }

  refreshPreview() {
    const iframe = document.querySelector('[data-lato-cms-page-preview-target="iframe"]')
    if (iframe && iframe.src) {
      const url = new URL(iframe.src)
      url.searchParams.set('_t', Date.now())
      iframe.src = url.toString()
      this.broadcastOpenComponent()
    }
  }

  broadcastOpenComponent() {
    const openCollapse = document.querySelector('#components-accordion .accordion-collapse.show')
    if (!openCollapse) return

    const templateComponentId = openCollapse.dataset.templateComponentId
    if (!templateComponentId) return

    const openItem = openCollapse.querySelector('.collapse.show[data-repeater-item-id]')

    document.dispatchEvent(new CustomEvent('lato-cms:component-change', {
      detail: {
        id: templateComponentId,
        templateComponentId,
        componentId: openCollapse.dataset.componentId,
        repeaterItemId: openItem?.dataset.repeaterItemId || null
      }
    }))
  }

  showStatus(message, type) {
    if (!this.hasStatusTarget) return

    clearTimeout(this._statusTimeout)

    const isSuccess = type === 'success'
    const icon = isSuccess ? 'bi-check-circle-fill' : 'bi-exclamation-circle-fill'
    const color = isSuccess ? 'text-success' : 'text-danger'

    this.statusTarget.innerHTML = `
      <span class="d-inline-flex align-items-center gap-1 small ${color} lato-cms-component-form__status">
        <i class="bi ${icon}" aria-hidden="true"></i>
      </span>`
    this.statusTarget.firstElementChild.append(document.createTextNode(message))

    // Only success fades out: an error stays until the next save.
    if (isSuccess) {
      this._statusTimeout = setTimeout(() => {
        const msg = this.statusTarget.querySelector('.lato-cms-component-form__status')
        if (msg) msg.classList.add('lato-cms-component-form__status--fade')
        setTimeout(() => { this.statusTarget.innerHTML = '' }, 400)
      }, 3000)
    }
  }
}
