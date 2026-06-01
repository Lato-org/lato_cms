import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['checkbox', 'stateLabel', 'stateIcon', 'stateWrapper', 'fieldsContainer', 'status']
  static values = {
    activeLabel: String,
    inactiveLabel: String,
    savingLabel: String,
    savedLabel: String,
    errorLabel: String
  }

  async toggle (event) {
    event.preventDefault()

    const form = event.currentTarget
    const formData = new FormData(form)
    const checkbox = this.checkboxTarget
    const enabled = checkbox.checked

    checkbox.disabled = true
    if (this.hasStatusTarget) {
      this.statusTarget.innerHTML = ''
    }

    try {
      const response = await fetch(form.action, {
        method: form.method.toUpperCase(),
        body: formData,
        headers: {
          Accept: 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        }
      })

      if (!response.ok) {
        throw new Error('toggle failed')
      }

      this.updateVisualState(enabled)
      if (this.hasStatusTarget) {
        this.statusTarget.innerHTML = ''
      }
    } catch (_error) {
      checkbox.checked = !enabled
      this.updateVisualState(!enabled)
      this.showStatus(this.errorLabelValue, 'danger')
    } finally {
      checkbox.disabled = false
    }
  }

  updateVisualState (enabled) {
    if (this.hasStateLabelTarget) {
      this.stateLabelTarget.textContent = enabled ? this.activeLabelValue : this.inactiveLabelValue
    }

    if (this.hasStateIconTarget) {
      this.stateIconTarget.className = enabled ? 'bi bi-eye' : 'bi bi-eye-slash'
    }

    if (this.hasStateWrapperTarget) {
      this.stateWrapperTarget.classList.toggle('text-success', enabled)
      this.stateWrapperTarget.classList.toggle('text-muted', !enabled)
    }

    const fieldsContainer = this.hasFieldsContainerTarget
      ? this.fieldsContainerTarget
      : this.element.querySelector('[data-lato-cms-component-toggle-target="fieldsContainer"]')

    if (fieldsContainer) {
      fieldsContainer.classList.toggle('d-none', !enabled)
    }
  }

  showStatus (message, type) {
    if (!this.hasStatusTarget) return

    const colorClass = type === 'success' ? 'text-success' : (type === 'danger' ? 'text-danger' : 'text-muted')
    this.statusTarget.innerHTML = `<span class="small ${colorClass}">${message}</span>`

    if (type === 'success') {
      clearTimeout(this._statusTimeout)
      this._statusTimeout = setTimeout(() => {
        this.statusTarget.innerHTML = ''
      }, 2000)
    }
  }
}
