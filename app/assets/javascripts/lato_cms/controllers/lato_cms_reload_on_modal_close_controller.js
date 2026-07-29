import { Controller } from '@hotwired/stimulus'

// Refreshes the enclosing turbo-frame (or the whole page) when the shared
// `lato_operation` progress modal closes — used after triggering a
// Lato::Operation (e.g. "Regenerate with AI", "Clone & translate") from a
// link inside it: the underlying page/frame has no way to know when that
// background job finishes, so once the admin dismisses the operation's
// progress modal, refresh so the result is shown without a manual reload.
//
// Only reacts when the modal that just closed actually contains the
// `#lato_operation` frame — every Bootstrap modal on the page fires
// `hidden.bs.modal`, including ones with nothing to do with an operation
// (e.g. this very form's own modal), and those must not trigger a reload.
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
    this.onModalHidden = this.onModalHidden.bind(this)
    document.addEventListener('hidden.bs.modal', this.onModalHidden)
  }

  disconnect () {
    document.removeEventListener('hidden.bs.modal', this.onModalHidden)
  }

  onModalHidden (event) {
    if (!event.target.querySelector('#lato_operation')) return

    const frame = this.element.closest('turbo-frame')
    if (frame && frame.getAttribute('src')) {
      frame.reload()
    } else {
      window.Turbo.visit(window.location.href)
    }
  }
}
