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
    // 从 URL 参数恢复筛选状态（优先级高于 storage）
    this.restoreFromUrlParams()

    if (this.storageKeyValue && !this.hasUrlParams()) {
      this.restoreFromStorage()
    }
    this.updateButtonCount()

    // 更新年份导航链接以保持筛选状态
    this.updateYearNavLinks()
  }

  // 检查 URL 是否有 category_ids 参数
  hasUrlParams() {
    const urlParams = new URLSearchParams(window.location.search)
    return urlParams.has('category_ids[]')
  }

  // 从 URL 参数恢复筛选状态
  restoreFromUrlParams() {
    const urlParams = new URLSearchParams(window.location.search)
    const urlCategoryIds = urlParams.getAll('category_ids[]').filter(id => id)

    if (urlCategoryIds.length === 0) return

    // 更新 hiddenCheckbox 状态
    this.hiddenCheckboxTargets.forEach(cb => {
      cb.checked = urlCategoryIds.includes(cb.value)
    })

    // 触发 change 事件让 report_tabs_controller 应用筛选
    this.hiddenCheckboxTargets.forEach(cb => {
      cb.dispatchEvent(new Event('change', { bubbles: true }))
    })
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
    const searchInput = modal.querySelector('[data-category-filter-target="searchInput"]')
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
    // 移除旧的事件处理器（如果存在）
    if (modal._eventHandlers) {
      const oldHandlers = modal._eventHandlers

      // 移除 close 按钮
      modal.querySelectorAll('[data-close-modal]').forEach(el => {
        if (oldHandlers.closeModal) el.removeEventListener('click', oldHandlers.closeModal)
      })

      // 移除背景点击
      const overlayBg = modal.querySelector('.modal-overlay-bg')
      if (overlayBg && oldHandlers.closeModal) {
        overlayBg.removeEventListener('click', oldHandlers.closeModal)
      }

      // 移除搜索输入
      const searchInput = modal.querySelector('[data-category-filter-target="searchInput"]')
      if (searchInput && oldHandlers.search) {
        searchInput.removeEventListener('input', oldHandlers.search)
      }

      // 移除 checkbox change
      modal.querySelectorAll('.category-filter-option').forEach(cb => {
        if (oldHandlers.checkboxChange) cb.removeEventListener('change', oldHandlers.checkboxChange)
      })

      // 移除按钮
      const selectAllBtn = modal.querySelector('[data-category-filter-target="selectAllBtn"]')
      if (selectAllBtn && oldHandlers.selectAll) {
        selectAllBtn.removeEventListener('click', oldHandlers.selectAll)
      }

      const clearAllBtn = modal.querySelector('[data-category-filter-target="clearBtn"]')
      if (clearAllBtn && oldHandlers.clearAll) {
        clearAllBtn.removeEventListener('click', oldHandlers.clearAll)
      }

      const confirmBtn = modal.querySelector('[data-category-filter-target="confirmBtn"]')
      if (confirmBtn && oldHandlers.confirm) {
        confirmBtn.removeEventListener('click', oldHandlers.confirm)
      }
    }

    // 创建新的处理器（使用箭头函数绑定当前 controller）
    const handlers = {}

    handlers.closeModal = () => {
      modal.classList.add('hidden')
    }

    // 绑定关闭按钮
    modal.querySelectorAll('[data-close-modal]').forEach(el => {
      el.addEventListener('click', handlers.closeModal)
    })

    // 绑定背景点击
    const overlayBg = modal.querySelector('.modal-overlay-bg')
    if (overlayBg) {
      overlayBg.addEventListener('click', handlers.closeModal)
    }

    // 绑定搜索
    const searchInput = modal.querySelector('[data-category-filter-target="searchInput"]')
    if (searchInput) {
      handlers.search = (e) => this.search(e)
      searchInput.addEventListener('input', handlers.search)
    }

    // 绑定 checkbox
    handlers.checkboxChange = (e) => {
      this.toggleDescendants(e.target)
      this.updateModalCount()
    }
    modal.querySelectorAll('.category-filter-option').forEach(cb => {
      cb.addEventListener('change', handlers.checkboxChange)
    })

    // 绑定按钮
    const selectAllBtn = modal.querySelector('[data-category-filter-target="selectAllBtn"]')
    if (selectAllBtn) {
      handlers.selectAll = () => this.selectAll()
      selectAllBtn.addEventListener('click', handlers.selectAll)
    }

    const clearAllBtn = modal.querySelector('[data-category-filter-target="clearBtn"]')
    if (clearAllBtn) {
      handlers.clearAll = () => this.clearAll()
      clearAllBtn.addEventListener('click', handlers.clearAll)
    }

    const confirmBtn = modal.querySelector('[data-category-filter-target="confirmBtn"]')
    if (confirmBtn) {
      handlers.confirm = () => this.confirm()
      confirmBtn.addEventListener('click', handlers.confirm)
    }

    // 保存处理器引用（供下次移除使用）
    modal._eventHandlers = handlers
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
    // 直接从弹窗获取选中状态并触发事件，不依赖 hiddenCheckbox
    const modal = this.getModal()
    if (modal) {
      const selectedIds = Array.from(modal.querySelectorAll('.category-filter-option'))
        .filter(cb => cb.checked)
        .map(cb => cb.value)

      // 同时更新 hiddenCheckbox 以保持一致性，并触发 change 事件
      this.hiddenCheckboxTargets.forEach(cb => {
        const wasChecked = cb.checked
        cb.checked = selectedIds.includes(cb.value)
        // 手动触发 change 事件，让 report_tabs_controller 能响应
        if (wasChecked !== cb.checked) {
          cb.dispatchEvent(new Event('change', { bubbles: true }))
        }
      })

      // 触发 Stimulus 自定义事件，使用弹窗的选中状态
      this.dispatch('change', { detail: { selectedIds }, bubbles: true })

      // 更新年份导航链接以保持筛选状态
      this.updateYearNavLinks()
    }
    if (this.storageKeyValue) {
      this.saveToStorage()
    }
    this.updateButtonCount()
  }

  // 更新年份导航链接，保持筛选状态
  updateYearNavLinks() {
    const yearNavController = this.getYearNavController()
    if (yearNavController) {
      yearNavController.updateLinks()
    }
  }

  // 获取 year-nav controller 实例
  getYearNavController() {
    const element = document.querySelector('[data-controller="year-nav"]')
    if (element && window.Stimulus) {
      return window.Stimulus.getControllerForElementAndIdentifier(element, 'year-nav')
    }
    return null
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