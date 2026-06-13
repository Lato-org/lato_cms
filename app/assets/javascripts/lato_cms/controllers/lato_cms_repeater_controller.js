import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['items', 'template', 'item', 'position', 'orderInput']

  add () {
    const itemId = window.crypto.randomUUID()
    const html = this.templateTarget.innerHTML
      .replaceAll('NEW_RECORD', itemId)
      .replaceAll('NEW_INDEX', this.itemTargets.length.toString())

    this.itemsTarget.insertAdjacentHTML('beforeend', html)
    this.refresh()
  }

  remove (event) {
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
  }
}
