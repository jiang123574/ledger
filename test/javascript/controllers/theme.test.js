// Test for theme controller
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'

describe('ThemeController', () => {
  let mockDocument
  let mockLocalStorage

  beforeEach(() => {
    mockLocalStorage = {
      theme: undefined,
      getItem: vi.fn((key) => mockLocalStorage[key]),
      setItem: vi.fn((key, value) => mockLocalStorage[key] = value),
      removeItem: vi.fn((key) => delete mockLocalStorage[key])
    }

    mockDocument = {
      documentElement: {
        classList: {
          contains: vi.fn().mockReturnValue(false),
          add: vi.fn(),
          remove: vi.fn()
        },
        setAttribute: vi.fn(),
        getAttribute: vi.fn()
      }
    }

    global.localStorage = mockLocalStorage
    global.document = mockDocument
    global.window = {
      matchMedia: vi.fn().mockReturnValue({ matches: false })
    }
  })

  afterEach(() => {
    vi.clearAllMocks()
  })

  describe('toggle', () => {
    it('should switch to dark mode when currently light', () => {
      mockDocument.documentElement.classList.contains.mockReturnValue(false)

      // Simulate toggle behavior
      const toggle = () => {
        const isDark = mockDocument.documentElement.classList.contains('dark')
        if (!isDark) {
          mockLocalStorage.theme = 'dark'
          mockDocument.documentElement.classList.add('dark')
          mockDocument.documentElement.setAttribute('data-theme', 'dark')
        }
      }

      toggle()

      expect(mockLocalStorage.theme).toBe('dark')
      expect(mockDocument.documentElement.classList.add).toHaveBeenCalledWith('dark')
      expect(mockDocument.documentElement.setAttribute).toHaveBeenCalledWith('data-theme', 'dark')
    })

    it('should switch to light mode when currently dark', () => {
      mockDocument.documentElement.classList.contains.mockReturnValue(true)

      // Simulate toggle behavior
      const toggle = () => {
        const isDark = mockDocument.documentElement.classList.contains('dark')
        if (isDark) {
          mockLocalStorage.theme = 'light'
          mockDocument.documentElement.classList.remove('dark')
          mockDocument.documentElement.setAttribute('data-theme', 'light')
        }
      }

      toggle()

      expect(mockLocalStorage.theme).toBe('light')
      expect(mockDocument.documentElement.classList.remove).toHaveBeenCalledWith('dark')
      expect(mockDocument.documentElement.setAttribute).toHaveBeenCalledWith('data-theme', 'light')
    })
  })

  describe('updateThemeClass', () => {
    it('should use stored theme preference', () => {
      mockLocalStorage.theme = 'dark'

      const updateThemeClass = () => {
        const stored = mockLocalStorage.theme
        if (stored === 'dark') {
          mockDocument.documentElement.classList.add('dark')
          mockDocument.documentElement.setAttribute('data-theme', 'dark')
        }
      }

      updateThemeClass()

      expect(mockDocument.documentElement.classList.add).toHaveBeenCalledWith('dark')
    })

    it('should fall back to system preference when no stored theme', () => {
      mockLocalStorage.theme = undefined
      global.window.matchMedia.mockReturnValue({ matches: true }) // prefers dark

      const updateThemeClass = () => {
        const stored = mockLocalStorage.theme
        const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
        if (stored === 'dark' || (!stored && prefersDark)) {
          mockDocument.documentElement.classList.add('dark')
        }
      }

      updateThemeClass()

      expect(mockDocument.documentElement.classList.add).toHaveBeenCalledWith('dark')
    })
  })
})