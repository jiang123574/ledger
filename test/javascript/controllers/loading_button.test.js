import { describe, it, expect, afterEach } from 'vitest'
import LoadingButtonController from '../../../app/javascript/controllers/loading_button_controller.js'
import { startController, stopController } from './stimulus_test_helper.js'

describe('LoadingButtonController', () => {
  let application

  afterEach(async () => {
    if (application) await stopController(application)
  })

  it('disables the target button and renders the configured loading text', async () => {
    ;({ application } = await startController('loading-button', LoadingButtonController, `
      <div data-controller="loading-button" data-loading-button-loading-text-value="Processing...">
        <button data-loading-button-target="button" data-action="click->loading-button#showLoading">Save</button>
      </div>
    `))

    const button = document.querySelector('button')
    button.click()

    expect(button.disabled).toBe(true)
    expect(button.getAttribute('aria-disabled')).toBe('true')
    expect(button.getAttribute('aria-busy')).toBe('true')
    expect(button.querySelector('.btn-spinner')).not.toBeNull()
    expect(button.textContent).toContain('Processing...')
  })

  it('uses the default loading text when no value is configured', async () => {
    ;({ application } = await startController('loading-button', LoadingButtonController, `
      <div data-controller="loading-button">
        <button data-loading-button-target="button" data-action="click->loading-button#showLoading">Save</button>
      </div>
    `))

    const button = document.querySelector('button')
    button.click()

    expect(button.textContent).toContain('Loading...')
  })

  it('does nothing when the button target is missing', async () => {
    ;({ application } = await startController('loading-button', LoadingButtonController, `
      <div data-controller="loading-button">
        <button data-action="click->loading-button#showLoading">Save</button>
      </div>
    `))

    const button = document.querySelector('button')
    expect(() => button.click()).not.toThrow()
    expect(button.disabled).toBe(false)
    expect(button.textContent).toBe('Save')
  })
})
