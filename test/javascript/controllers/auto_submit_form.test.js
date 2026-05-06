import { describe, it, expect, vi, afterEach } from 'vitest'
import AutoSubmitFormController from '../../../app/javascript/controllers/auto_submit_form_controller.js'
import { startController, stopController } from './stimulus_test_helper.js'

describe('AutoSubmitFormController', () => {
  let application

  afterEach(async () => {
    vi.useRealTimers()
    if (application) await stopController(application)
  })

  async function mountForm(markup) {
    document.body.innerHTML = markup
    const form = document.querySelector('form')
    form.requestSubmit = vi.fn()

    ;({ application } = await startController('auto-submit-form', AutoSubmitFormController, document.body.innerHTML))
    return document.querySelector('form')
  }

  it('submits text inputs on blur after the debounce delay', async () => {
    vi.useFakeTimers()
    const form = await mountForm(`
      <form data-controller="auto-submit-form">
        <input type="text" name="q">
      </form>
    `)

    form.querySelector('input').dispatchEvent(new Event('blur', { bubbles: true }))
    expect(form.requestSubmit).not.toHaveBeenCalled()

    vi.advanceTimersByTime(499)
    expect(form.requestSubmit).not.toHaveBeenCalled()

    vi.advanceTimersByTime(1)
    expect(form.requestSubmit).toHaveBeenCalledTimes(1)
  })

  it('submits number inputs immediately on change', async () => {
    const form = await mountForm(`
      <form data-controller="auto-submit-form">
        <input type="number" name="amount">
      </form>
    `)

    form.querySelector('input').dispatchEvent(new Event('change', { bubbles: true }))
    expect(form.requestSubmit).toHaveBeenCalledTimes(1)
  })

  it('debounces repeated text input blur events', async () => {
    vi.useFakeTimers()
    const form = await mountForm(`
      <form data-controller="auto-submit-form">
        <textarea name="notes"></textarea>
      </form>
    `)
    const textarea = form.querySelector('textarea')

    textarea.dispatchEvent(new Event('blur', { bubbles: true }))
    vi.advanceTimersByTime(300)
    textarea.dispatchEvent(new Event('blur', { bubbles: true }))
    vi.advanceTimersByTime(500)

    expect(form.requestSubmit).toHaveBeenCalledTimes(1)
  })

  it('falls back to submit when requestSubmit is unavailable', async () => {
    document.body.innerHTML = `
      <form data-controller="auto-submit-form">
        <select name="category"><option>A</option></select>
      </form>
    `
    const originalRequestSubmit = HTMLFormElement.prototype.requestSubmit
    HTMLFormElement.prototype.requestSubmit = undefined
    const form = document.querySelector('form')
    form.submit = vi.fn()

    ;({ application } = await startController('auto-submit-form', AutoSubmitFormController, document.body.innerHTML))
    const mountedForm = document.querySelector('form')
    mountedForm.submit = form.submit
    mountedForm.querySelector('select').dispatchEvent(new Event('change', { bubbles: true }))

    expect(mountedForm.submit).toHaveBeenCalledTimes(1)
    HTMLFormElement.prototype.requestSubmit = originalRequestSubmit
  })
})
