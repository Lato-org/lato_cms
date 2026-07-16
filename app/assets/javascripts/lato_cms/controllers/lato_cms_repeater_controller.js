import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['items', 'template', 'item', 'position', 'orderInput', 'addButton']
  static values = { min: { type: Number, default: 0 }, max: { type: Number, default: 0 } }

  connect () {
    this.refresh()
  }

  add () {
    // Guard against exceeding max even if the button state is stale.
    if (this.maxValue > 0 && this.itemTargets.length >= this.maxValue) return

    const itemId = window.crypto.randomUUID()
    const html = this.templateTarget.innerHTML
      .replaceAll('NEW_RECORD', itemId)
      .replaceAll('NEW_INDEX', this.itemTargets.length.toString())

    this.itemsTarget.insertAdjacentHTML('beforeend', html)
    this.refresh()
  }

  remove (event) {
    // Block removal below the required minimum.
    if (this.minValue > 0 && this.itemTargets.length <= this.minValue) return

    const item = event.currentTarget.closest('[data-lato-cms-repeater-target="item"]')
    if (!item) return

    item.remove()
    this.refresh()
  }

  refresh () {
    this.itemTargets.forEach((item, index) => {
      const position = item.querySelector('[data-lato-cms-repeater-target="position"]')
      if (position) position.textContent = index + 1

      const orderInput = item.querySelector('[data-lato-cms-repeater-target="orderInput"]')
      if (orderInput) orderInput.value = item.dataset.repeaterItemId
    })

    this.updateControls()
  }

  // Toggle add/remove availability against the min/max constraints.
  updateControls () {
    const count = this.itemTargets.length

    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = this.maxValue > 0 && count >= this.maxValue
    }

    const disableRemove = this.minValue > 0 && count <= this.minValue
    this.itemTargets.forEach((item) => {
      const removeButton = item.querySelector('[data-action~="lato-cms-repeater#remove"]')
      if (removeButton) removeButton.disabled = disableRemove
    })
  }
}
