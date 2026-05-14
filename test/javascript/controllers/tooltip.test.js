import { describe, it, expect, vi, afterEach } from 'vitest'
import TooltipController from '../../../app/javascript/controllers/tooltip_controller.js'
import { startController, stopController } from './stimulus_test_helper.js'

// Mock @floating-ui/dom
vi.mock('@floating-ui/dom', () => ({
  autoUpdate: () => () => {},
  computePosition: () => Promise.resolve({ x: 0, y: 0 }),
  flip: () => {},
  offset: () => {},
  shift: () => {}
}))

describe('TooltipController', () => {
  let application

  afterEach(async () => {
    vi.useRealTimers()
    vi.clearAllMocks()
    if (application) await stopController(application)
  })

  async function mountTooltip() {
    const result = await startController('tooltip', TooltipController, `
      <span data-controller="tooltip" data-tooltip-placement-value="top">
        <span data-icon>Hover me</span>
        <div data-tooltip-target="tooltip" class="hidden">Tooltip text here</div>
      </span>
    `)
    application = result.application
    return result.element
  }

  it('shows tooltip on mouseenter', async () => {
    const element = await mountTooltip()
    const trigger = element.querySelector('[data-icon]')
    const tooltip = element.querySelector('[data-tooltip-target="tooltip"]')

    expect(tooltip.classList.contains('hidden')).toBe(true)

    trigger.dispatchEvent(new MouseEvent('mouseenter', { bubbles: true }))

    expect(tooltip.classList.contains('hidden')).toBe(false)
  })

  it('hides tooltip on mouseleave', async () => {
    const element = await mountTooltip()
    const trigger = element.querySelector('[data-icon]')
    const tooltip = element.querySelector('[data-tooltip-target="tooltip"]')

    trigger.dispatchEvent(new MouseEvent('mouseenter', { bubbles: true }))
    expect(tooltip.classList.contains('hidden')).toBe(false)

    trigger.dispatchEvent(new MouseEvent('mouseleave', { bubbles: true }))

    expect(tooltip.classList.contains('hidden')).toBe(true)
  })

  it('uses element as reference when no data-icon present', async () => {
    const result = await startController('tooltip', TooltipController, `
      <span data-controller="tooltip">
        Simple text
        <div data-tooltip-target="tooltip" class="hidden">Tooltip</div>
      </span>
    `)
    application = result.application
    const element = result.element
    const tooltip = element.querySelector('[data-tooltip-target="tooltip"]')

    element.dispatchEvent(new MouseEvent('mouseenter', { bubbles: true }))

    expect(tooltip.classList.contains('hidden')).toBe(false)
  })
})