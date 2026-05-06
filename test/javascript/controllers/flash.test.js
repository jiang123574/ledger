import { describe, it, expect, vi, afterEach } from 'vitest'
import FlashController from '../../../app/javascript/controllers/flash_controller.js'
import { startController, stopController } from './stimulus_test_helper.js'

describe('FlashController', () => {
  let application

  afterEach(async () => {
    vi.useRealTimers()
    if (application) await stopController(application)
  })

  it('auto-dismisses after three seconds', async () => {
    vi.useFakeTimers()

    ;({ application } = await startController('flash', FlashController, `
      <div data-controller="flash">Saved</div>
    `))

    const flash = document.querySelector('[data-controller="flash"]')
    vi.advanceTimersByTime(3000)

    expect(flash.style.transition).toBe('opacity 0.3s ease-out')
    expect(flash.style.opacity).toBe('0')

    vi.advanceTimersByTime(300)
    expect(document.querySelector('[data-controller="flash"]')).toBeNull()
  })
})
