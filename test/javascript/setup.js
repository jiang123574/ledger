// Vitest setup file for Stimulus controller tests
import { vi } from 'vitest'

// Mock window globals that controllers might use
global.window = {
  showConfirmDialog: vi.fn().mockResolvedValue(true),
  closeConfirmDialog: vi.fn(),
  confirm: vi.fn().mockReturnValue(true),
  localStorage: {
    getItem: vi.fn(),
    setItem: vi.fn(),
    removeItem: vi.fn(),
    clear: vi.fn()
  },
  matchMedia: vi.fn().mockReturnValue({ matches: false })
}

global.document = {
  createElement: vi.fn().mockReturnValue({
    classList: { add: vi.fn(), remove: vi.fn(), contains: vi.fn().mockReturnValue(false) },
    setAttribute: vi.fn(),
    addEventListener: vi.fn()
  }),
  querySelector: vi.fn(),
  querySelectorAll: vi.fn().mockReturnValue([])
}

// Mock Stimulus Application
vi.mock('@hotwired/stimulus', () => ({
  Controller: class Controller {
    constructor() {
      this.element = document.createElement('div')
      this.targets = {}
      this.values = {}
    }
    connect() {}
    disconnect() {}
  }
}))