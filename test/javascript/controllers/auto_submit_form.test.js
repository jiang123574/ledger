import { describe, it, expect, vi, afterEach } from 'vitest'
import AutoSubmitFormController from '../../../app/javascript/controllers/auto_submit_form_controller.js'
import { startController, stopController } from './stimulus_test_helper.js'

describe('AutoSubmitFormController', () => {
  let application
  let requestSubmitSpy

  afterEach(async () => {
    vi.useRealTimers()
    if (application) await stopController(application)
    requestSubmitSpy?.mockRestore()
    requestSubmitSpy = null
  })

  async function mountForm(markup) {
    requestSubmitSpy = vi.spyOn(HTMLFormElement.prototype, 'requestSubmit').mockImplementation(() => {})
    ;({ application } = await startController('auto-submit-form', AutoSubmitFormController, markup))
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
    expect(requestSubmitSpy).not.toHaveBeenCalled()

    vi.advanceTimersByTime(499)
    expect(requestSubmitSpy).not.toHaveBeenCalled()

    vi.advanceTimersByTime(1)
    expect(requestSubmitSpy).toHaveBeenCalledTimes(1)
  })

  it('submits number inputs immediately on change', async () => {
    const form = await mountForm(`
      <form data-controller="auto-submit-form">
        <input type="number" name="amount">
      </form>
    `)

    form.querySelector('input').dispatchEvent(new Event('change', { bubbles: true }))
    expect(requestSubmitSpy).toHaveBeenCalledTimes(1)
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

    expect(requestSubmitSpy).toHaveBeenCalledTimes(1)
  })

  it('falls back to submit when requestSubmit is unavailable', async () => {
    const originalRequestSubmit = HTMLFormElement.prototype.requestSubmit
    HTMLFormElement.prototype.requestSubmit = undefined

    ;({ application } = await startController('auto-submit-form', AutoSubmitFormController, `
      <form data-controller="auto-submit-form">
        <select name="category"><option>A</option></select>
      </form>
    `))

    const form = document.querySelector('form')
    form.submit = vi.fn()
    form.querySelector('select').dispatchEvent(new Event('change', { bubbles: true }))

    expect(form.submit).toHaveBeenCalledTimes(1)
    HTMLFormElement.prototype.requestSubmit = originalRequestSubmit
  })
})
