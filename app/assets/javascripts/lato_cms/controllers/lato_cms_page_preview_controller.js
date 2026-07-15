import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['iframe', 'viewport', 'deviceBtn', 'customWidth', 'dimensions']

  connect () {
    this.handleComponentChange = this.handleComponentChange.bind(this)
    this.handleIframeLoad = this.handleIframeLoad.bind(this)

    document.addEventListener('lato-cms:component-change', this.handleComponentChange)

    if (this.hasIframeTarget) {
      this.iframeTarget.addEventListener('load', this.handleIframeLoad)

      // Live viewport dimensions readout
      if (window.ResizeObserver) {
        this.resizeObserver = new window.ResizeObserver(() => this.updateDimensions())
        this.resizeObserver.observe(this.iframeTarget)
      }
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

    if (this.resizeObserver) this.resizeObserver.disconnect()
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

  // Constrain the preview iframe to a device viewport width.
  setDevice (event) {
    if (!this.hasViewportTarget) return

    const device = event.currentTarget.dataset.device

    this.iframeTarget.style.maxWidth = ''
    this.viewportTarget.classList.remove(
      'lato-cms-page-preview__viewport--tablet',
      'lato-cms-page-preview__viewport--mobile',
      'lato-cms-page-preview__viewport--custom'
    )
    if (device !== 'desktop') {
      this.viewportTarget.classList.add(`lato-cms-page-preview__viewport--${device}`)
    }

    this.deviceBtnTargets.forEach(btn => {
      btn.classList.toggle('active', btn.dataset.device === device)
    })

    if (this.hasCustomWidthTarget) this.customWidthTarget.value = ''
  }

  // Constrain the preview iframe to a user-defined width (px).
  setCustomWidth () {
    if (!this.hasViewportTarget || !this.hasCustomWidthTarget) return

    const width = parseInt(this.customWidthTarget.value, 10)

    this.deviceBtnTargets.forEach(btn => btn.classList.remove('active'))
    this.viewportTarget.classList.remove(
      'lato-cms-page-preview__viewport--tablet',
      'lato-cms-page-preview__viewport--mobile'
    )

    if (Number.isFinite(width) && width > 0) {
      this.viewportTarget.classList.add('lato-cms-page-preview__viewport--custom')
      this.iframeTarget.style.maxWidth = `${width}px`
    } else {
      // Empty/invalid input → revert to desktop
      this.viewportTarget.classList.remove('lato-cms-page-preview__viewport--custom')
      this.iframeTarget.style.maxWidth = ''
      this.deviceBtnTargets.forEach(btn => {
        btn.classList.toggle('active', btn.dataset.device === 'desktop')
      })
    }
  }

  updateDimensions () {
    if (!this.hasIframeTarget || !this.hasDimensionsTarget) return

    const rect = this.iframeTarget.getBoundingClientRect()
    this.dimensionsTarget.textContent = `${Math.round(rect.width)} × ${Math.round(rect.height)} px`
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
