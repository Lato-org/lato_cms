import { Controller } from '@hotwired/stimulus'

// Submits a file form over XHR so the real upload progress can be shown.
// Neither of the two alternatives can: a plain form submit just freezes the
// page until the server answers, and `fetch` exposes no upload progress
// events at all (only download ones). Large videos made that gap obvious.
//
// On success it dispatches `lato-cms:upload-complete` on the form with the
// parsed JSON body (the media picker uses it to select the fresh media), or
// navigates to `redirectUrlValue` when the form is a standalone page.
export default class extends Controller {
  static targets = ['progress', 'bar', 'label', 'submit', 'notice']
  static values = { redirectUrl: String, processingLabel: String, confirm: String }

  submit (event) {
    // This handler owns the submission, so Turbo never sees it and
    // `data-turbo-confirm` would never fire: the confirmation is asked here.
    event.preventDefault()
    if (this.confirmValue && !window.confirm(this.confirmValue)) return

    const xhr = new window.XMLHttpRequest()
    xhr.open('POST', this.element.action, true)
    xhr.setRequestHeader('Accept', 'application/json')
    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable) this.setProgress((e.loaded / e.total) * 100)
    })
    xhr.addEventListener('load', () => this.finish(xhr))
    xhr.addEventListener('error', () => this.fail())

    this.start()
    xhr.send(new window.FormData(this.element))
  }

  start () {
    this.clearNotice()
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
    if (this.hasProgressTarget) this.progressTarget.classList.remove('d-none')
    this.setProgress(0)
  }

  // Past 100% the bytes are in, but the server is still attaching and
  // processing them: the bar stays full and animated, the label says so.
  setProgress (percent) {
    const value = Math.round(percent)
    if (this.hasBarTarget) this.barTarget.style.width = `${value}%`
    if (this.hasLabelTarget) this.labelTarget.textContent = value >= 100 ? this.processingLabelValue : `${value}%`
  }

  finish (xhr) {
    const data = this.parse(xhr.responseText)

    if (xhr.status < 200 || xhr.status >= 300) {
      this.fail(data)
      return
    }

    if (this.redirectUrlValue) {
      window.Turbo.visit(this.redirectUrlValue)
      return
    }

    this.reset()
    this.element.reset()
    this.element.dispatchEvent(new CustomEvent('lato-cms:upload-complete', { bubbles: true, detail: data }))
  }

  fail (data) {
    this.reset()
    const message = data ? Object.values(data).flat().join(', ') : ''
    this.element.dispatchEvent(new CustomEvent('lato-cms:upload-error', { bubbles: true, detail: { message } }))
    if (this.hasNoticeTarget) this.noticeTarget.innerHTML = `<div class="alert alert-danger">${message}</div>`
  }

  reset () {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
    if (this.hasProgressTarget) this.progressTarget.classList.add('d-none')
    this.setProgress(0)
  }

  clearNotice () {
    if (this.hasNoticeTarget) this.noticeTarget.innerHTML = ''
  }

  parse (body) {
    try {
      return JSON.parse(body)
    } catch (err) {
      return null
    }
  }
}
