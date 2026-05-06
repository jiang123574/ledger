import { describe, it, expect, vi, afterEach } from 'vitest'
import AlertController from '../../../app/javascript/controllers/alert_controller.js'
import { startController, stopController } from './stimulus_test_helper.js'

describe('AlertController', () => {
  let application

  afterEach(async () => {
    vi.useRealTimers()
    if (application) await stopController(application)
  })

  it('fades and removes the controller element when dismissed', async () => {
    vi.useFakeTimers()

    ;({ application } = await startController('alert--dismissible', AlertController, `
      <div data-controller="alert--dismissible">
        <button data-action="alert--dismissible#dismiss">Close</button>
      </div>
    `))

    const alert = document.querySelector('[data-controller="alert--dismissible"]')
    alert.querySelector('button').click()

    expect(alert.style.opacity).toBe('0')
    expect(alert.style.transform).toBe('translateY(-10px)')

    vi.advanceTimersByTime(300)
    expect(document.querySelector('[data-controller="alert--dismissible"]')).toBeNull()
  })
})
