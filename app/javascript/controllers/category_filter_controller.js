import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", "searchInput", "option", "item", "selectAllBtn", "clearBtn", "confirmBtn",
    "countBadge", "hiddenCheckbox"
  ]

  static values = {
    storageKey: String,
    filterGroup: String,
    modalSelector: String
  }

  connect() {
    if (this.storageKeyValue) {
      this.restoreFromStorage()
    }
    this.updateButtonCount()
  }

  getModal() {
    if (this.hasModalTarget) {
      return this.modalTarget
    }
    if (this.modalSelectorValue) {
      return document.querySelector(this.modalSelectorValue)
    }
    return null
  }

  open() {
    const modal = this.getModal()
    if (!modal) return
    this.syncToModal()
    modal.classList.remove('hidden')
    const searchInput = modal.querySelector('[data-category-filter-target="searchInput"]') || modal.querySelector('input[type="text"]')
    if (searchInput) {
      searchInput.value = ''
      searchInput.focus()
    }
    // 重置所有分类项的显示状态（清除之前的搜索过滤）
    modal.querySelectorAll('.category-filter-item').forEach(item => {
      item.style.display = ''
    })
    this.updateModalCount()
    this.bindModalEvents(modal)
  }

  bindModalEvents(modal) {
    if (modal._boundClose) return

    const closeModal = () => {
      modal.classList.add('hidden')
    }

    modal.querySelectorAll('[data-close-modal]').forEach(el => {
      el.addEventListener('click', closeModal)
    })

    // 绑定搜索输入框事件
    const searchInput = modal.querySelector('[data-category-filter-target="searchInput"]') || modal.querySelector('input[type="text"][placeholder*="搜索"]')
    if (searchInput) {
      searchInput.addEventListener('input', (e) => this.search(e))
    }

    modal.querySelectorAll('.category-filter-option').forEach(cb => {
      cb.addEventListener('change', (e) => {
        this.toggleDescendants(e.target)
        this.updateModalCount()
      })
    })

    const selectAllBtn = modal.querySelector('[data-category-filter-target="selectAllBtn"]') || modal.querySelector('[id$="-select-all"]')
    if (selectAllBtn) {
      selectAllBtn.addEventListener('click', () => this.selectAll())
    }

    const clearAllBtn = modal.querySelector('[data-category-filter-target="clearBtn"]') || modal.querySelector('[id$="-clear-all"]')
    if (clearAllBtn) {
      clearAllBtn.addEventListener('click', () => this.clearAll())
    }

    const confirmBtn = modal.querySelector('[data-category-filter-target="confirmBtn"]') || modal.querySelector('[id$="-confirm"]')
    if (confirmBtn) {
      confirmBtn.addEventListener('click', () => this.confirm())
    }

    modal._boundClose = closeModal
  }

  close() {
    const modal = this.getModal()
    if (modal) modal.classList.add('hidden')
  }

  search(event) {
    const modal = this.getModal()
    if (!modal) return
    const keyword = event.target.value.toLowerCase().trim()
    modal.querySelectorAll('.category-filter-item').forEach(item => {
      const name = (item.dataset.name || '').toLowerCase()
      const fullName = (item.dataset.fullName || '').toLowerCase()
      const pinyin = (item.dataset.pinyin || '').toLowerCase()
      const match = name.includes(keyword) || fullName.includes(keyword) || pinyin.includes(keyword)
      item.style.display = match ? '' : 'none'
    })
  }

  selectAll() {
    const modal = this.getModal()
    if (!modal) return
    modal.querySelectorAll('.category-filter-option').forEach(cb => cb.checked = true)
    this.updateModalCount()
  }

  clearAll() {
    const modal = this.getModal()
    if (!modal) return
    modal.querySelectorAll('.category-filter-option').forEach(cb => cb.checked = false)
    this.updateModalCount()
  }

  confirm() {
    this.close()
    this.syncFromModal()
    if (this.storageKeyValue) {
      this.saveToStorage()
    }
    this.dispatchChange()
    this.updateButtonCount()
  }

  toggleOption(event) {
    this.toggleDescendants(event.target)
    this.updateModalCount()
  }

  syncToModal() {
    const modal = this.getModal()
    if (!modal) return

    // 从 URL 参数获取当前选中状态（比 hiddenCheckbox 更可靠）
    const urlParams = new URLSearchParams(window.location.search)
    const urlSelectedIds = urlParams.getAll('category_ids[]').filter(id => id)

    // 如果 URL 参数为空，尝试从 hiddenCheckbox 获取
    let selectedIds = urlSelectedIds
    if (selectedIds.length === 0) {
      selectedIds = this.hiddenCheckboxTargets
        .filter(cb => cb.checked)
        .map(cb => cb.value)
    }

    modal.querySelectorAll('.category-filter-option').forEach(cb => {
      cb.checked = selectedIds.includes(cb.value)
    })
  }

  syncFromModal() {
    const modal = this.getModal()
    if (!modal) return
    const selectedIds = Array.from(modal.querySelectorAll('.category-filter-option'))
      .filter(cb => cb.checked)
      .map(cb => cb.value)

    this.hiddenCheckboxTargets.forEach(cb => {
      cb.checked = selectedIds.includes(cb.value)
    })
  }

  getDescendantIds(parentId) {
    const modal = this.getModal()
    if (!modal) return []
    const descendants = []
    modal.querySelectorAll('.category-filter-option').forEach(cb => {
      if (cb.dataset.parentId === String(parentId)) {
        descendants.push(parseInt(cb.dataset.id, 10))
        descendants.push(...this.getDescendantIds(cb.dataset.id))
      }
    })
    return descendants
  }

  toggleDescendants(cb) {
    const modal = this.getModal()
    if (!modal) return
    const parentId = cb.dataset.id
    if (!parentId) return

    const descendantIds = this.getDescendantIds(parentId)
    descendantIds.forEach(id => {
      const descCb = modal.querySelector(`.category-filter-option[data-id="${id}"]`)
      if (descCb) descCb.checked = cb.checked
    })
  }

  updateModalCount() {
    const modal = this.getModal()
    if (!modal) return
    const checked = Array.from(modal.querySelectorAll('.category-filter-option')).filter(cb => cb.checked).length
    if (this.hasCountBadgeTarget) {
      this.countBadgeTarget.textContent = checked
    }
  }

  updateButtonCount() {
    const checked = this.hiddenCheckboxTargets.filter(cb => cb.checked).length
    if (this.hasCountBadgeTarget) {
      this.countBadgeTarget.textContent = checked
    }
  }

  restoreFromStorage() {
    const stored = localStorage.getItem(this.storageKeyValue)
    if (!stored) return

    const storedIds = JSON.parse(stored)
    this.hiddenCheckboxTargets.forEach(cb => {
      cb.checked = storedIds.includes(cb.value)
    })

    this.dispatch('restore', { detail: { selectedIds: storedIds } })
  }

  saveToStorage() {
    const modal = this.getModal()
    if (!modal) return
    const selectedIds = Array.from(modal.querySelectorAll('.category-filter-option'))
      .filter(cb => cb.checked)
      .map(cb => cb.value)
    localStorage.setItem(this.storageKeyValue, JSON.stringify(selectedIds))
  }

  dispatchChange() {
    const selectedIds = this.hiddenCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
    this.dispatch('change', { detail: { selectedIds }, bubbles: true })
  }
}