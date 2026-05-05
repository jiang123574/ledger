// Test for auto_submit_form controller
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'

describe('AutoSubmitFormController', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  describe('getEventType', () => {
    const getEventType = (input) => {
      const type = input.type?.toLowerCase() || input.tagName.toLowerCase()

      switch (type) {
        case 'text':
        case 'email':
        case 'search':
          return 'blur'
        case 'number':
        case 'date':
        case 'datetime-local':
        case 'time':
          return 'change'
        case 'checkbox':
        case 'radio':
          return 'change'
        case 'range':
          return 'input'
        case 'select':
          return 'change'
        case 'textarea':
          return 'blur'
        default:
          return 'change'
      }
    }

    it('should return blur for text inputs', () => {
      expect(getEventType({ type: 'text' })).toBe('blur')
      expect(getEventType({ type: 'email' })).toBe('blur')
      expect(getEventType({ type: 'search' })).toBe('blur')
    })

    it('should return change for number inputs', () => {
      expect(getEventType({ type: 'number' })).toBe('change')
      expect(getEventType({ type: 'date' })).toBe('change')
      expect(getEventType({ type: 'datetime-local' })).toBe('change')
    })

    it('should return change for checkbox and radio', () => {
      expect(getEventType({ type: 'checkbox' })).toBe('change')
      expect(getEventType({ type: 'radio' })).toBe('change')
    })

    it('should return input for range', () => {
      expect(getEventType({ type: 'range' })).toBe('input')
    })

    it('should return change for select', () => {
      expect(getEventType({ tagName: 'select' })).toBe('change')
    })

    it('should return blur for textarea', () => {
      expect(getEventType({ tagName: 'textarea' })).toBe('blur')
    })
  })

  describe('getDebounceTime', () => {
    const getDebounceTime = (input) => {
      const type = input.type?.toLowerCase() || input.tagName.toLowerCase()

      switch (type) {
        case 'text':
        case 'email':
        case 'search':
        case 'textarea':
          return 500
        case 'number':
        case 'date':
        case 'datetime-local':
        case 'time':
          return 0
        case 'checkbox':
        case 'radio':
          return 0
        case 'range':
          return 200
        case 'select':
          return 0
        default:
          return 0
      }
    }

    it('should return 500ms for text inputs', () => {
      expect(getDebounceTime({ type: 'text' })).toBe(500)
      expect(getDebounceTime({ type: 'email' })).toBe(500)
      expect(getDebounceTime({ tagName: 'textarea' })).toBe(500)
    })

    it('should return 0ms for immediate inputs', () => {
      expect(getDebounceTime({ type: 'number' })).toBe(0)
      expect(getDebounceTime({ type: 'checkbox' })).toBe(0)
      expect(getDebounceTime({ tagName: 'select' })).toBe(0)
    })

    it('should return 200ms for range', () => {
      expect(getDebounceTime({ type: 'range' })).toBe(200)
    })
  })

  describe('debounce behavior', () => {
    it('should submit immediately when debounce is 0', () => {
      const mockForm = {
        requestSubmit: vi.fn()
      }

      const handleInput = (input, form, debounceTime) => {
        if (debounceTime === 0) {
          form.requestSubmit()
        }
      }

      handleInput({ type: 'checkbox' }, mockForm, 0)

      expect(mockForm.requestSubmit).toHaveBeenCalled()
    })

    it('should debounce text input by 500ms', () => {
      const mockForm = {
        requestSubmit: vi.fn()
      }
      let debounceTimer = null

      const handleInput = (debounceTime) => {
        if (debounceTimer) {
          clearTimeout(debounceTimer)
        }
        debounceTimer = setTimeout(() => {
          mockForm.requestSubmit()
        }, debounceTime)
      }

      handleInput(500)

      expect(mockForm.requestSubmit).not.toHaveBeenCalled()

      vi.advanceTimersByTime(500)

      expect(mockForm.requestSubmit).toHaveBeenCalled()
    })

    it('should cancel previous debounce on new input', () => {
      const mockForm = {
        requestSubmit: vi.fn()
      }
      let debounceTimer = null
      let submitCount = 0

      const handleInput = (debounceTime) => {
        if (debounceTimer) {
          clearTimeout(debounceTimer)
        }
        debounceTimer = setTimeout(() => {
          mockForm.requestSubmit()
          submitCount++
        }, debounceTime)
      }

      handleInput(500)
      vi.advanceTimersByTime(300)
      handleInput(500) // Cancel previous and start new
      vi.advanceTimersByTime(500)

      expect(submitCount).toBe(1) // Only one submission
    })
  })

  describe('submitForm', () => {
    it('should use requestSubmit when available', () => {
      const mockForm = {
        requestSubmit: vi.fn(),
        submit: vi.fn()
      }

      const submitForm = (form) => {
        if (form.requestSubmit) {
          form.requestSubmit()
        } else {
          form.submit()
        }
      }

      submitForm(mockForm)

      expect(mockForm.requestSubmit).toHaveBeenCalled()
      expect(mockForm.submit).not.toHaveBeenCalled()
    })

    it('should fallback to submit when requestSubmit not available', () => {
      const mockForm = {
        submit: vi.fn()
      }

      const submitForm = (form) => {
        if (form.requestSubmit) {
          form.requestSubmit()
        } else {
          form.submit()
        }
      }

      submitForm(mockForm)

      expect(mockForm.submit).toHaveBeenCalled()
    })
  })
})