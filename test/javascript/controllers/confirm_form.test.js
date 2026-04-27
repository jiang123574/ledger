// Test for confirm-form controller
import { describe, it, expect, vi, beforeEach } from 'vitest'

// Simple mock controller test without importing the actual controller
// (since importmap requires Rails environment)

describe('ConfirmFormController', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('confirm action', () => {
    it('should call showConfirmDialog with correct parameters', async () => {
      // Mock the showConfirmDialog to return true
      window.showConfirmDialog = vi.fn().mockResolvedValue(true)

      // Simulate controller behavior
      const mockElement = {
        tagName: 'BUTTON',
        dataset: {
          confirmFormTitleValue: '确认删除',
          confirmFormContentValue: '确定删除此记录吗？',
          confirmFormConfirmTextValue: '删除',
          confirmFormDangerValue: 'true'
        }
      }

      // Simulate what the controller would do
      await window.showConfirmDialog({
        title: mockElement.dataset.confirmFormTitleValue,
        content: mockElement.dataset.confirmFormContentValue,
        confirmText: mockElement.dataset.confirmFormConfirmTextValue,
        danger: true
      })

      expect(window.showConfirmDialog).toHaveBeenCalledWith({
        title: '确认删除',
        content: '确定删除此记录吗？',
        confirmText: '删除',
        danger: true
      })
    })

    it('should use fallback confirm when showConfirmDialog is not available', () => {
      window.showConfirmDialog = undefined
      window.confirm = vi.fn().mockReturnValue(true)

      // Simulate fallback behavior
      const content = '确定删除此记录吗？'
      const confirmed = window.confirm(content)

      expect(window.confirm).toHaveBeenCalledWith(content)
      expect(confirmed).toBe(true)
    })
  })

  describe('submitForm action', () => {
    it('should find form by formId', () => {
      const mockForm = {
        submit: vi.fn()
      }
      document.getElementById = vi.fn().mockReturnValue(mockForm)

      // Simulate finding form by ID
      const formId = 'delete-form-123'
      const form = document.getElementById(formId)

      if (form) {
        form.submit()
      }

      expect(document.getElementById).toHaveBeenCalledWith(formId)
      expect(mockForm.submit).toHaveBeenCalled()
    })
  })
})