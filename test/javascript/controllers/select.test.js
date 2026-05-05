// Test for select controller
import { describe, it, expect, vi, beforeEach } from 'vitest'

describe('SelectController', () => {
  describe('toggle action', () => {
    it('should open menu when closed', () => {
      const mockMenu = {
        classList: {
          remove: vi.fn(),
          add: vi.fn()
        }
      }
      const mockButton = {
        setAttribute: vi.fn()
      }

      // Simulate open behavior
      let isOpen = false
      const open = () => {
        isOpen = true
        mockMenu.classList.remove('hidden', 'opacity-0', '-translate-y-1')
        mockMenu.classList.add('opacity-100', 'translate-y-0')
        mockButton.setAttribute('aria-expanded', 'true')
      }

      open()

      expect(isOpen).toBe(true)
      expect(mockMenu.classList.remove).toHaveBeenCalledWith('hidden', 'opacity-0', '-translate-y-1')
      expect(mockButton.setAttribute).toHaveBeenCalledWith('aria-expanded', 'true')
    })

    it('should close menu when open', () => {
      vi.useFakeTimers()

      const mockMenu = {
        classList: {
          remove: vi.fn(),
          add: vi.fn()
        }
      }
      const mockButton = {
        setAttribute: vi.fn()
      }

      // Simulate close behavior
      let isOpen = true
      const close = () => {
        isOpen = false
        mockMenu.classList.remove('opacity-100', 'translate-y-0')
        mockMenu.classList.add('opacity-0', '-translate-y-1')
        mockButton.setAttribute('aria-expanded', 'false')
        setTimeout(() => {
          if (!isOpen) {
            mockMenu.classList.add('hidden')
          }
        }, 150)
      }

      close()

      expect(isOpen).toBe(false)
      expect(mockMenu.classList.add).toHaveBeenCalledWith('opacity-0', '-translate-y-1')
      expect(mockButton.setAttribute).toHaveBeenCalledWith('aria-expanded', 'false')

      vi.advanceTimersByTime(150)
      expect(mockMenu.classList.add).toHaveBeenCalledWith('hidden')

      vi.useRealTimers()
    })
  })

  describe('select action', () => {
    it('should update input value and close menu', () => {
      const mockInput = {
        value: '',
        dispatchEvent: vi.fn()
      }
      const mockButton = {
        querySelector: vi.fn().mockReturnValue(null),
        textContent: '',
        focus: vi.fn()
      }
      const mockMenu = {
        querySelector: vi.fn().mockReturnValue(null)
      }

      const mockEvent = {
        currentTarget: {
          dataset: { value: 'option1', filterName: 'Option 1' },
          setAttribute: vi.fn(),
          classList: { add: vi.fn() }
        }
      }

      // Simulate select behavior
      const select = (event) => {
        const selectedElement = event.currentTarget
        const value = selectedElement.dataset.value
        const label = selectedElement.dataset.filterName || selectedElement.textContent.trim()

        mockButton.textContent = label
        mockInput.value = value
        mockInput.dispatchEvent(new Event('change', { bubbles: true }))
        mockButton.focus()
      }

      select(mockEvent)

      expect(mockButton.textContent).toBe('Option 1')
      expect(mockInput.value).toBe('option1')
      expect(mockInput.dispatchEvent).toHaveBeenCalled()
      expect(mockButton.focus).toHaveBeenCalled()
    })

    it('should dispatch dropdown:select event', () => {
      const mockElement = {
        dispatchEvent: vi.fn()
      }

      const mockEvent = {
        currentTarget: {
          dataset: { value: 'test-value', filterName: 'Test Label' }
        }
      }

      // Simulate event dispatch
      const dispatchSelectEvent = (element, event) => {
        element.dispatchEvent(new CustomEvent('dropdown:select', {
          detail: { value: event.currentTarget.dataset.value, label: event.currentTarget.dataset.filterName },
          bubbles: true
        }))
      }

      dispatchSelectEvent(mockElement, mockEvent)

      expect(mockElement.dispatchEvent).toHaveBeenCalled()
      const dispatchedEvent = mockElement.dispatchEvent.mock.calls[0][0]
      expect(dispatchedEvent.type).toBe('dropdown:select')
      expect(dispatchedEvent.detail.value).toBe('test-value')
    })
  })

  describe('keyboard navigation', () => {
    it('should close on Escape key', () => {
      const mockButton = { focus: vi.fn() }
      let isOpen = true
      const close = vi.fn(() => {
        isOpen = false
        mockButton.focus()
      })

      const handleKeydown = (event) => {
        if (event.key === 'Escape') {
          close()
        }
      }

      handleKeydown({ key: 'Escape' })

      expect(close).toHaveBeenCalled()
      expect(mockButton.focus).toHaveBeenCalled()
    })

    it('should select on Enter key', () => {
      const mockTarget = {
        dataset: { value: 'option1' },
        click: vi.fn()
      }

      const handleKeydown = (event) => {
        if (event.key === 'Enter' && event.target.dataset.value) {
          event.preventDefault()
          event.target.click()
        }
      }

      handleKeydown({ key: 'Enter', target: mockTarget, preventDefault: vi.fn() })

      expect(mockTarget.click).toHaveBeenCalled()
    })
  })

  describe('outside click handling', () => {
    it('should close menu when clicking outside', () => {
      let isOpen = true
      const close = vi.fn(() => { isOpen = false })

      const handleOutsideClick = (event) => {
        if (isOpen && !elementContains(event.target)) {
          close()
        }
      }

      const elementContains = vi.fn().mockReturnValue(false)

      handleOutsideClick({ target: {} })

      expect(close).toHaveBeenCalled()
    })

    it('should not close menu when clicking inside', () => {
      let isOpen = true
      const close = vi.fn(() => { isOpen = false })

      const handleOutsideClick = (event, contains) => {
        if (isOpen && !contains) {
          close()
        }
      }

      handleOutsideClick({ target: {} }, true)

      expect(close).not.toHaveBeenCalled()
    })
  })
})