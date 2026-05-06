import { afterEach, vi } from 'vitest'

function createMatchMedia(matches = false) {
  return vi.fn().mockReturnValue({
    matches,
    media: '',
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn()
  })
}

Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: createMatchMedia()
})

if (!Element.prototype.scrollIntoView) {
  Element.prototype.scrollIntoView = vi.fn()
}

Object.defineProperty(navigator, 'clipboard', {
  configurable: true,
  value: { writeText: vi.fn() }
})

Object.defineProperty(navigator, 'share', {
  configurable: true,
  value: undefined
})

afterEach(() => {
  document.body.innerHTML = ''
  document.documentElement.className = ''
  document.documentElement.removeAttribute('data-theme')
  localStorage.clear()
  delete localStorage.theme
  delete window.LedgerNative
  vi.restoreAllMocks()

  window.matchMedia = createMatchMedia()
  Object.defineProperty(navigator, 'clipboard', {
    configurable: true,
    value: { writeText: vi.fn() }
  })
  Object.defineProperty(navigator, 'share', {
    configurable: true,
    value: undefined
  })
})
