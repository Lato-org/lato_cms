import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['iframe']

  connect () {
    this.handleComponentChange = this.handleComponentChange.bind(this)
    this.handleIframeLoad = this.handleIframeLoad.bind(this)

    document.addEventListener('lato-cms:component-change', this.handleComponentChange)

    if (this.hasIframeTarget) {
      this.iframeTarget.addEventListener('load', this.handleIframeLoad)
    }

    window.requestAnimationFrame(() => {
      this.syncInitiallyOpenComponent()
    })
  }

  disconnect () {
    document.removeEventListener('lato-cms:component-change', this.handleComponentChange)

    if (this.hasIframeTarget) {
      this.iframeTarget.removeEventListener('load', this.handleIframeLoad)
    }
  }

  refresh () {
    if (!this.hasIframeTarget) return

    const iframe = this.iframeTarget
    if (iframe.src) {
      const url = new URL(iframe.src, window.location.href)
      url.searchParams.set('_t', Date.now())
      iframe.src = url.toString()
    }
  }

  handleComponentChange (event) {
    this.activeComponent = event.detail
    this.postActiveComponent()
  }

  handleIframeLoad () {
    this.postActiveComponent()
  }

  syncInitiallyOpenComponent () {
    const openCollapse = document.querySelector('#components-accordion .accordion-collapse.show')
    if (!openCollapse) return

    const templateComponentId = openCollapse.dataset.templateComponentId
    if (!templateComponentId) return

    this.activeComponent = {
      id: templateComponentId,
      templateComponentId,
      componentId: openCollapse.dataset.componentId
    }

    this.postActiveComponent()
  }

  postActiveComponent () {
    if (!this.hasIframeTarget || !this.activeComponent) return

    const iframeWindow = this.iframeTarget.contentWindow
    if (!iframeWindow) return

    iframeWindow.postMessage({
      type: 'lato-cms:component-change',
      ...this.activeComponent
    }, this.targetOrigin())
  }

  targetOrigin () {
    if (!this.iframeTarget.src) return window.location.origin

    try {
      return new URL(this.iframeTarget.src, window.location.href).origin
    } catch (_error) {
      return window.location.origin
    }
  }
}
