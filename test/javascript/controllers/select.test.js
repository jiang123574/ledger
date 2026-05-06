import { describe, it, expect, vi, afterEach } from 'vitest'
import SelectController from '../../../app/javascript/controllers/select_controller.js'
import { startController, stopController } from './stimulus_test_helper.js'

describe('SelectController', () => {
  let application

  afterEach(async () => {
    vi.useRealTimers()
    if (application) await stopController(application)
  })

  async function mountSelect() {
    const result = await startController('select', SelectController, `
      <div data-controller="select">
        <input data-select-target="input" type="hidden" name="choice">
        <button data-select-target="button" data-action="click->select#toggle" aria-expanded="false">
          <span>Choose</span>
        </button>
        <div data-select-target="menu" class="hidden opacity-0 -translate-y-1">
          <div data-action="click->select#select" data-value="one" data-filter-name="Option One">One</div>
          <div data-action="click->select#select" data-value="two">Option Two</div>
        </div>
      </div>
    `)
    application = result.application
    return result.element
  }

  it('opens and closes the menu through the toggle action', async () => {
    vi.useFakeTimers()
    const element = await mountSelect()
    const button = element.querySelector('button')
    const menu = element.querySelector('[data-select-target="menu"]')

    button.click()
    expect(menu.classList.contains('hidden')).toBe(false)
    expect(menu.classList.contains('opacity-100')).toBe(true)
    expect(button.getAttribute('aria-expanded')).toBe('true')

    button.click()
    expect(menu.classList.contains('opacity-0')).toBe(true)
    expect(button.getAttribute('aria-expanded')).toBe('false')

    vi.advanceTimersByTime(150)
    expect(menu.classList.contains('hidden')).toBe(true)
  })

  it('updates the hidden input, button label, selected state, and custom event', async () => {
    const element = await mountSelect()
    const input = element.querySelector('input')
    const button = element.querySelector('button')
    const option = element.querySelector('[data-value="one"]')
    const change = vi.fn()
    const selected = vi.fn()

    input.addEventListener('change', change)
    element.addEventListener('dropdown:select', selected)

    option.click()

    expect(input.value).toBe('one')
    expect(change).toHaveBeenCalledTimes(1)
    expect(button.textContent).toContain('Option One')
    expect(option.getAttribute('aria-selected')).toBe('true')
    expect(option.classList.contains('bg-gray-100')).toBe(true)
    expect(selected).toHaveBeenCalledTimes(1)
    expect(selected.mock.calls[0][0].detail).toEqual({ value: 'one', label: 'Option One' })
  })

  it('closes on Escape and selects the focused option on Enter', async () => {
    vi.useFakeTimers()
    const element = await mountSelect()
    const button = element.querySelector('button')
    const option = element.querySelector('[data-value="two"]')
    const input = element.querySelector('input')

    button.click()
    element.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
    vi.advanceTimersByTime(150)
    expect(element.querySelector('[data-select-target="menu"]').classList.contains('hidden')).toBe(true)

    button.click()
    option.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }))
    expect(input.value).toBe('two')
  })

  it('closes when clicking outside the controller element', async () => {
    vi.useFakeTimers()
    const element = await mountSelect()
    const button = element.querySelector('button')
    const menu = element.querySelector('[data-select-target="menu"]')

    button.click()
    document.body.dispatchEvent(new MouseEvent('click', { bubbles: true }))
    vi.advanceTimersByTime(150)

    expect(menu.classList.contains('hidden')).toBe(true)
  })
})
