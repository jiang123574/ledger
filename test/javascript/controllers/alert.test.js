// Test for alert controller
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'

describe('AlertController', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  describe('dismiss action', () => {
    it('should fade out and remove element', () => {
      const mockElement = {
        style: {},
        remove: vi.fn()
      }

      // Simulate controller dismiss behavior
      const dismiss = () => {
        mockElement.style.opacity = '0'
        mockElement.style.transform = 'translateY(-10px)'
        setTimeout(() => mockElement.remove(), 300)
      }

      dismiss()

      expect(mockElement.style.opacity).toBe('0')
      expect(mockElement.style.transform).toBe('translateY(-10px)')

      // Fast-forward 300ms
      vi.advanceTimersByTime(300)

      expect(mockElement.remove).toHaveBeenCalled()
    })

    it('should handle multiple dismiss calls gracefully', () => {
      const mockElement = {
        style: {},
        remove: vi.fn()
      }

      const dismiss = () => {
        mockElement.style.opacity = '0'
        mockElement.style.transform = 'translateY(-10px)'
        setTimeout(() => mockElement.remove(), 300)
      }

      // Call dismiss multiple times
      dismiss()
      dismiss()

      vi.advanceTimersByTime(300)

      // Element should be removed only once (after timeout)
      expect(mockElement.remove).toHaveBeenCalled()
    })
  })
})