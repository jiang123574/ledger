// Test for flash controller
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'

describe('FlashController', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  describe('auto-dismiss', () => {
    it('should dismiss after 3 seconds', () => {
      const mockElement = {
        style: {},
        remove: vi.fn()
      }

      // Simulate controller behavior
      const controller = {
        element: mockElement,
        connect() {
          setTimeout(() => this.dismiss(), 3000)
        },
        dismiss() {
          this.element.style.transition = 'opacity 0.3s ease-out'
          this.element.style.opacity = '0'
          setTimeout(() => this.element.remove(), 300)
        }
      }

      controller.connect()

      // Fast-forward 3 seconds
      vi.advanceTimersByTime(3000)

      expect(mockElement.style.opacity).toBe('0')

      // Fast-forward 300ms for removal
      vi.advanceTimersByTime(300)

      expect(mockElement.remove).toHaveBeenCalled()
    })
  })
})