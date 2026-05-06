import { describe, it, expect, vi, afterEach } from 'vitest'
import ThemeController from '../../../app/javascript/controllers/theme_controller.js'
import { startController, stopController } from './stimulus_test_helper.js'

describe('ThemeController', () => {
  let application

  afterEach(async () => {
    if (application) await stopController(application)
    localStorage.clear()
  })

  async function mountTheme() {
    const result = await startController('theme', ThemeController, `
      <div data-controller="theme">
        <input data-theme-target="toggle" type="checkbox">
        <button data-action="click->theme#toggle">Toggle</button>
        <span data-theme-icon="sun" class="hidden">sun</span>
        <span data-theme-icon="moon">moon</span>
      </div>
    `)
    application = result.application
    return result.element
  }

  it('applies a stored dark theme on connect', async () => {
    localStorage.theme = 'dark'

    const element = await mountTheme()

    expect(document.documentElement.classList.contains('dark')).toBe(true)
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark')
    expect(element.querySelector('[data-theme-target="toggle"]').checked).toBe(true)
    expect(element.querySelector('[data-theme-icon="sun"]').classList.contains('hidden')).toBe(false)
    expect(element.querySelector('[data-theme-icon="moon"]').classList.contains('hidden')).toBe(true)
  })

  it('uses system dark preference when no stored theme exists', async () => {
    window.matchMedia = vi.fn().mockReturnValue({ matches: true })

    await mountTheme()

    expect(window.matchMedia).toHaveBeenCalledWith('(prefers-color-scheme: dark)')
    expect(document.documentElement.classList.contains('dark')).toBe(true)
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark')
  })

  it('toggles between dark and light themes', async () => {
    window.matchMedia = vi.fn().mockReturnValue({ matches: false })
    const element = await mountTheme()
    const button = element.querySelector('button')
    const toggle = element.querySelector('[data-theme-target="toggle"]')

    button.click()
    expect(localStorage.theme).toBe('dark')
    expect(document.documentElement.classList.contains('dark')).toBe(true)
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark')
    expect(toggle.checked).toBe(true)

    button.click()
    expect(localStorage.theme).toBe('light')
    expect(document.documentElement.classList.contains('dark')).toBe(false)
    expect(document.documentElement.getAttribute('data-theme')).toBe('light')
    expect(toggle.checked).toBe(false)
  })
})
