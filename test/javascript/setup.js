import { afterEach, vi } from 'vitest'

if (!window.matchMedia) {
  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    value: vi.fn().mockReturnValue({
      matches: false,
      media: '',
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn()
    })
  })
}

if (!Element.prototype.scrollIntoView) {
  Element.prototype.scrollIntoView = vi.fn()
}

if (!navigator.clipboard) {
  Object.defineProperty(navigator, 'clipboard', {
    configurable: true,
    value: { writeText: vi.fn() }
  })
}

afterEach(() => {
  document.body.innerHTML = ''
  document.documentElement.className = ''
  document.documentElement.removeAttribute('data-theme')
  delete window.LedgerNative
  vi.restoreAllMocks()
})
