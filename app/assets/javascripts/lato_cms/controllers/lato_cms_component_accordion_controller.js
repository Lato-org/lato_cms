import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect () {
    this.handleShown = this.handleShown.bind(this)
    this.handleHidden = this.handleHidden.bind(this)

    this.element.addEventListener('shown.bs.collapse', this.handleShown)
    this.element.addEventListener('hidden.bs.collapse', this.handleHidden)

    window.requestAnimationFrame(() => {
      this.broadcastInitiallyOpenComponent()
    })
  }

  disconnect () {
    this.element.removeEventListener('shown.bs.collapse', this.handleShown)
    this.element.removeEventListener('hidden.bs.collapse', this.handleHidden)
  }

  handleShown (event) {
    this.broadcastForCollapse(event.target)
  }

  handleHidden () {
    this.broadcastClosedComponent()
  }

  broadcastInitiallyOpenComponent () {
    const openCollapse = this.element.querySelector('.accordion-collapse.show')
    if (!openCollapse) return

    this.broadcastForCollapse(openCollapse)
  }

  broadcastForCollapse (collapseElement) {
    const templateComponentId = collapseElement.dataset.templateComponentId
    const componentId = collapseElement.dataset.componentId

    if (!templateComponentId) return

    document.dispatchEvent(new CustomEvent('lato-cms:component-change', {
      detail: {
        id: templateComponentId,
        templateComponentId,
        componentId
      }
    }))
  }

  broadcastClosedComponent () {
    document.dispatchEvent(new CustomEvent('lato-cms:component-change', {
      detail: {
        id: null,
        templateComponentId: null,
        componentId: null
      }
    }))
  }
}
