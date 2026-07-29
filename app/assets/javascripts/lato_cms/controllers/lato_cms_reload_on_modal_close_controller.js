import { Controller } from '@hotwired/stimulus'

// Refreshes the enclosing turbo-frame (or the whole page) whenever a
// Bootstrap modal on the page closes. Used after triggering a
// Lato::Operation (e.g. "Regenerate with AI", "Clone & translate") from a
// link inside it: the underlying page/frame has no way to know when that
// background job finishes, so once the admin dismisses the operation's
// progress modal, refresh so the result is shown without a manual reload.
//
// Mounted on an element INSIDE the turbo-frame's content, not on the frame
// tag itself: when this frame is opened inside a modal, `lato-action`
// pre-creates a bare `<turbo-frame>` via innerHTML before Turbo fetches
// into it, and Turbo's frame navigation only replaces that element's
// children, not its own attributes — a `data-controller` set directly on
// the frame tag in the fetched content would never actually attach.
// `closest('turbo-frame')` finds the frame at the time of reload, whether
// this connected inside a modal-loaded frame or a plain, directly-loaded
// page (no frame at all, so it falls back to reloading the whole page).
export default class extends Controller {
  connect () {
    this.reload = this.reload.bind(this)
    document.addEventListener('hidden.bs.modal', this.reload)
  }

  disconnect () {
    document.removeEventListener('hidden.bs.modal', this.reload)
  }

  reload () {
    const frame = this.element.closest('turbo-frame')
    if (frame && frame.getAttribute('src')) {
      frame.reload()
    } else {
      window.Turbo.visit(window.location.href)
    }
  }
}
