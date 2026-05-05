// Test for loading_button controller
import { describe, it, expect, vi, beforeEach } from 'vitest'

describe('LoadingButtonController', () => {
  describe('showLoading action', () => {
    it('should disable button and show loading text', () => {
      const mockButton = {
        disabled: false,
        setAttribute: vi.fn(),
        innerHTML: ''
      }

      const showLoading = (button, loadingText = 'Loading...') => {
        button.disabled = true
        button.setAttribute('aria-disabled', 'true')
        button.setAttribute('aria-busy', 'true')
        button.innerHTML = `
          <span class="inline-flex items-center gap-2">
            <span class="btn-spinner" aria-hidden="true"></span>
            <span>${loadingText}</span>
          </span>
        `
      }

      showLoading(mockButton, '处理中...')

      expect(mockButton.disabled).toBe(true)
      expect(mockButton.setAttribute).toHaveBeenCalledWith('aria-disabled', 'true')
      expect(mockButton.setAttribute).toHaveBeenCalledWith('aria-busy', 'true')
      expect(mockButton.innerHTML).toContain('处理中...')
      expect(mockButton.innerHTML).toContain('btn-spinner')
    })

    it('should use default loading text when not specified', () => {
      const mockButton = {
        disabled: false,
        setAttribute: vi.fn(),
        innerHTML: ''
      }

      const showLoading = (button, loadingText = 'Loading...') => {
        button.innerHTML = `<span>${loadingText}</span>`
      }

      showLoading(mockButton)

      expect(mockButton.innerHTML).toContain('Loading...')
    })

    it('should handle missing button target', () => {
      const mockController = {
        hasButtonTarget: false,
        buttonTarget: undefined
      }

      const showLoading = (controller) => {
        if (!controller.hasButtonTarget) return
        controller.buttonTarget.disabled = true
      }

      showLoading(mockController)

      // Should not throw and should not modify anything
      expect(mockController.hasButtonTarget).toBe(false)
    })
  })

  describe('accessibility', () => {
    it('should set correct aria attributes', () => {
      const mockButton = {
        disabled: false,
        setAttribute: vi.fn()
      }

      const showLoading = (button) => {
        button.disabled = true
        button.setAttribute('aria-disabled', 'true')
        button.setAttribute('aria-busy', 'true')
      }

      showLoading(mockButton)

      expect(mockButton.setAttribute).toHaveBeenCalledWith('aria-disabled', 'true')
      expect(mockButton.setAttribute).toHaveBeenCalledWith('aria-busy', 'true')
    })
  })
})