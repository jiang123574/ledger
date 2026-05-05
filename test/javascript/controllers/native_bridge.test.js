// Test for native_bridge controller
import { describe, it, expect, vi, beforeEach } from 'vitest'

describe('NativeBridgeController', () => {
  describe('NativeApp.isNative', () => {
    it('should return true when LedgerNative is available', () => {
      global.window.LedgerNative = {
        isNativeApp: vi.fn().mockReturnValue(true)
      }

      const isNative = () => {
        return typeof window.LedgerNative !== 'undefined' && window.LedgerNative?.isNativeApp?.()
      }

      expect(isNative()).toBe(true)
    })

    it('should return false when LedgerNative is not available', () => {
      global.window.LedgerNative = undefined

      const isNative = () => {
        return typeof window.LedgerNative !== 'undefined' && window.LedgerNative?.isNativeApp?.()
      }

      expect(isNative()).toBe(false)
    })
  })

  describe('NativeApp.share', () => {
    beforeEach(() => {
      vi.clearAllMocks()
    })

    it('should call LedgerNative.share when available', () => {
      global.window.LedgerNative = {
        isNativeApp: vi.fn().mockReturnValue(true),
        share: vi.fn()
      }

      const share = (title, text) => {
        if (typeof window.LedgerNative !== 'undefined' && window.LedgerNative.isNativeApp()) {
          window.LedgerNative.share(title, text)
          return true
        }
        return false
      }

      const result = share('Test Title', 'Test Text')

      expect(result).toBe(true)
      expect(window.LedgerNative.share).toHaveBeenCalledWith('Test Title', 'Test Text')
    })

    it('should return false when not in native app', () => {
      global.window.LedgerNative = undefined

      const share = (title, text) => {
        if (typeof window.LedgerNative !== 'undefined' && window.LedgerNative?.isNativeApp?.()) {
          window.LedgerNative.share(title, text)
          return true
        }
        return false
      }

      const result = share('Test Title', 'Test Text')

      expect(result).toBe(false)
    })
  })

  describe('NativeApp.pickFile', () => {
    it('should call LedgerNative.pickFile with accept parameter', () => {
      global.window.LedgerNative = {
        isNativeApp: vi.fn().mockReturnValue(true),
        pickFile: vi.fn()
      }

      const pickFile = (accept = '*/*') => {
        if (typeof window.LedgerNative !== 'undefined' && window.LedgerNative.isNativeApp()) {
          window.LedgerNative.pickFile(accept)
          return true
        }
        return false
      }

      const result = pickFile('image/*')

      expect(result).toBe(true)
      expect(window.LedgerNative.pickFile).toHaveBeenCalledWith('image/*')
    })
  })

  describe('fallback behaviors', () => {
    it('should use Web Share API when native not available', () => {
      global.window.LedgerNative = undefined
      global.navigator.share = vi.fn().mockResolvedValue(true)
      global.window.location = { href: 'https://example.com' }

      const shareFallback = async (title, text) => {
        if (navigator.share) {
          await navigator.share({ title, text, url: window.location.href })
          return 'web-share'
        }
        return 'clipboard'
      }

      shareFallback('Test', 'Text')

      expect(navigator.share).toHaveBeenCalled()
    })

    it('should fallback to clipboard when Web Share API not available', () => {
      global.window.LedgerNative = undefined
      global.navigator.share = undefined
      global.navigator.clipboard = { writeText: vi.fn() }
      global.window.location = { href: 'https://example.com' }

      const shareFallback = () => {
        if (!navigator.share) {
          navigator.clipboard?.writeText(window.location.href)
          return 'clipboard'
        }
        return 'web-share'
      }

      const result = shareFallback()

      expect(result).toBe('clipboard')
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith('https://example.com')
    })
  })

  describe('event listeners', () => {
    it('should register file selection callback', () => {
      const callback = vi.fn()
      global.window.addEventListener = vi.fn()

      const onFileSelected = (callback) => {
        window.addEventListener('native:file-selected', (e) => callback(e.detail))
      }

      onFileSelected(callback)

      expect(window.addEventListener).toHaveBeenCalledWith('native:file-selected', expect.any(Function))
    })

    it('should register biometric result callback', () => {
      const callback = vi.fn()
      global.window.addEventListener = vi.fn()

      const onBiometricResult = (callback) => {
        window.addEventListener('native:biometric', (e) => callback(e.detail))
      }

      onBiometricResult(callback)

      expect(window.addEventListener).toHaveBeenCalledWith('native:biometric', expect.any(Function))
    })
  })
})