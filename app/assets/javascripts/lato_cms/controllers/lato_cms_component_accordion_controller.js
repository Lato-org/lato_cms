import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect () {
    this.handleToggle = this.handleToggle.bind(this)

    this.element.addEventListener('shown.bs.collapse', this.handleToggle)
    this.element.addEventListener('hidden.bs.collapse', this.handleToggle)

    window.requestAnimationFrame(() => {
      this.broadcastCurrentSelection()
    })
  }

  disconnect () {
    this.element.removeEventListener('shown.bs.collapse', this.handleToggle)
    this.element.removeEventListener('hidden.bs.collapse', this.handleToggle)
  }

  // Repeater items are nested collapses, so their events bubble up here, and
  // opening one item closes its sibling: the events alone don't tell what ends
  // up open. Read the selection off the DOM once it has settled instead.
  handleToggle () {
    window.requestAnimationFrame(() => {
      this.broadcastCurrentSelection()
    })
  }

  // The open component, narrowed to the open repeater item when there is one.
  broadcastCurrentSelection () {
    const openComponent = this.element.querySelector('.accordion-collapse.show')
    if (!openComponent) {
      this.broadcastClosedComponent()
      return
    }

    const openItem = openComponent.querySelector('.collapse.show[data-repeater-item-id]')
    this.broadcastForCollapse(openItem || openComponent)
  }

  broadcastForCollapse (collapseElement) {
    const templateComponentId = collapseElement.dataset.templateComponentId
    const componentId = collapseElement.dataset.componentId
    const repeaterItemId = collapseElement.dataset.repeaterItemId

    if (!templateComponentId) return

    document.dispatchEvent(new CustomEvent('lato-cms:component-change', {
      detail: {
        id: templateComponentId,
        templateComponentId,
        componentId,
        repeaterItemId: repeaterItemId || null
      }
    }))
  }

  broadcastClosedComponent () {
    document.dispatchEvent(new CustomEvent('lato-cms:component-change', {
      detail: {
        id: null,
        templateComponentId: null,
        componentId: null,
        repeaterItemId: null
      }
    }))
  }
}
