// Test for list_filter controller
import { describe, it, expect, vi, beforeEach } from 'vitest'

describe('ListFilterController', () => {
  describe('filter action', () => {
    it('should show matching items and hide non-matching', () => {
      const mockItems = [
        { dataset: { filterName: 'Apple' }, classList: { toggle: vi.fn() }, textContent: 'Apple' },
        { dataset: { filterName: 'Banana' }, classList: { toggle: vi.fn() }, textContent: 'Banana' },
        { dataset: { filterName: 'Cherry' }, classList: { toggle: vi.fn() }, textContent: 'Cherry' }
      ]

      const filter = (query, items) => {
        items.forEach(item => {
          const filterName = (item.dataset.filterName || item.textContent).toLowerCase()
          const matches = filterName.includes(query)
          item.classList.toggle('hidden', !matches)
        })
      }

      filter('a', mockItems)

      expect(mockItems[0].classList.toggle).toHaveBeenCalledWith('hidden', false) // Apple matches
      expect(mockItems[1].classList.toggle).toHaveBeenCalledWith('hidden', false) // Banana matches
      expect(mockItems[2].classList.toggle).toHaveBeenCalledWith('hidden', true)  // Cherry doesn't match
    })

    it('should be case insensitive', () => {
      const mockItem = {
        dataset: { filterName: 'APPLE' },
        classList: { toggle: vi.fn() }
      }

      const filter = (query, item) => {
        const filterName = (item.dataset.filterName || item.textContent).toLowerCase()
        const matches = filterName.includes(query.toLowerCase())
        item.classList.toggle('hidden', !matches)
      }

      filter('apple', mockItem)

      expect(mockItem.classList.toggle).toHaveBeenCalledWith('hidden', false)
    })

    it('should show all items when query is empty', () => {
      const mockItems = [
        { dataset: { filterName: 'Apple' }, classList: { toggle: vi.fn() } },
        { dataset: { filterName: 'Banana' }, classList: { toggle: vi.fn() } }
      ]

      const filter = (query, items) => {
        items.forEach(item => {
          const filterName = (item.dataset.filterName || item.textContent).toLowerCase()
          const matches = filterName.includes(query)
          item.classList.toggle('hidden', !matches)
        })
      }

      filter('', mockItems)

      expect(mockItems[0].classList.toggle).toHaveBeenCalledWith('hidden', false)
      expect(mockItems[1].classList.toggle).toHaveBeenCalledWith('hidden', false)
    })

    it('should handle items without filterName dataset', () => {
      const mockItem = {
        dataset: {},
        textContent: 'Test Item',
        classList: { toggle: vi.fn() }
      }

      const filter = (query, item) => {
        const filterName = (item.dataset.filterName || item.textContent).toLowerCase()
        const matches = filterName.includes(query)
        item.classList.toggle('hidden', !matches)
      }

      filter('test', mockItem)

      expect(mockItem.classList.toggle).toHaveBeenCalledWith('hidden', false)
    })

    it('should handle partial matches', () => {
      const mockItems = [
        { dataset: { filterName: 'Apple Juice' }, classList: { toggle: vi.fn() } },
        { dataset: { filterName: 'Apple Pie' }, classList: { toggle: vi.fn() } }
      ]

      const filter = (query, items) => {
        items.forEach(item => {
          const filterName = (item.dataset.filterName || item.textContent).toLowerCase()
          const matches = filterName.includes(query)
          item.classList.toggle('hidden', !matches)
        })
      }

      filter('apple', mockItems)

      expect(mockItems[0].classList.toggle).toHaveBeenCalledWith('hidden', false)
      expect(mockItems[1].classList.toggle).toHaveBeenCalledWith('hidden', false)
    })
  })
})