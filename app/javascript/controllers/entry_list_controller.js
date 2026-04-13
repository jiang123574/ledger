import { Controller } from "@hotwired/stimulus"
import { renderEntryCards, renderLoading, renderError } from "entry_card_renderer"

export default class extends Controller {
  static targets = ["container"]
  static values = {
    accountId: String,
    page: Number,
    perPage: Number,
    totalCount: Number,
    periodType: String,
    periodValue: String,
    filterType: String,
    search: String,
    categoryIds: String,
    dragEnabled: { type: Boolean, default: true }
  }

  connect() {
    // 如果元素是 hidden 的，跳过初始化
    if (this.element.classList.contains('hidden')) {
      return;
    }

    this.isLoading = false
    this.currentPage = this.pageValue
    this.dragStartHandler = this.handleDragStart.bind(this)
    this.dragOverHandler = this.handleDragOver.bind(this)
    this.dropHandler = this.handleDrop.bind(this)
    this.dragEndHandler = this.handleDragEnd.bind(this)
    this.setupIntersectionObserver()
    this.setupDragAndDrop()
    window.loadMoreEntries = () => {
      if (!this.isLoading) {
        this.loadMore()
      }
    }
  }

  setupLoadMoreButton() {
    // Button click is handled via onclick attribute in HTML
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.containerTarget) {
      const items = this.containerTarget.querySelectorAll('[data-entry-id]')
      items.forEach((item) => this.removeDragHandlers(item))
    }
  }

  setupIntersectionObserver() {
    const sentinel = document.getElementById("load-more-sentinel")
    if (!sentinel) return

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting && !this.isLoading) {
          this.loadMore()
        }
      })
    }, { rootMargin: "100px" })

    this.observer.observe(sentinel)
  }

  loadMore() {
    if (this.isLoading) return

    const totalPages = Math.ceil(this.totalCountValue / this.perPageValue)
    if (this.currentPage >= totalPages) {
      document.getElementById("load-more-sentinel")?.classList.add("hidden")
      return
    }

    this.isLoading = true
    this.showLoadingIndicator()

    const nextPage = this.currentPage + 1
    this.fetchEntries(nextPage)
  }

  fetchEntries(page) {
    const params = new URLSearchParams()
    params.set("page", page)
    params.set("per_page", this.perPageValue)
    params.set("format", "json")

    if (this.accountIdValue) params.set("account_id", this.accountIdValue)
    if (this.periodTypeValue) params.set("period_type", this.periodTypeValue)
    if (this.periodValueValue) params.set("period_value", this.periodValueValue)
    if (this.filterTypeValue) params.set("type", this.filterTypeValue)
    if (this.searchValue) params.set("search", this.searchValue)
    if (this.categoryIdsValue) {
      this.categoryIdsValue.split(",").forEach((id) => {
        if (id) params.append("category_ids[]", id)
      })
    }

    fetch(`/accounts/entries?${params.toString()}`, {
      headers: { "X-Requested-With": "XMLHttpRequest" }
    })
      .then((r) => r.json())
      .then((data) => {
        this.appendEntries(data.entries)
        this.currentPage = page
        this.hideLoadingIndicator()
        this.isLoading = false

        if (page * this.perPageValue >= this.totalCountValue) {
          document.getElementById("load-more-sentinel")?.classList.add("hidden")
        }
      })
      .catch((err) => {
        console.error("Failed to load entries:", err)
        this.hideLoadingIndicator()
        this.isLoading = false
      })
  }

  appendEntries(entries) {
    entries.forEach((entry) => {
      const card = window.EntryCardRenderer.createEntryCard(entry, {
        onEdit: (id) => {
          if (window.openEditTransactionModal) {
            window.openEditTransactionModal(id)
          } else {
            console.warn("openEditTransactionModal not found")
          }
        },
        onDelete: (id, name) => {
          if (window.confirmDeleteTransaction) {
            window.confirmDeleteTransaction(id, name)
          } else {
            console.warn("confirmDeleteTransaction not found")
          }
        },
        dragEnabled: !!this.accountIdValue
      })
      
      // 只在特定账户页面添加拖拽监听器
      if (this.accountIdValue && this.dragEnabledValue) {
        this.addDragHandlers(card)
      }
      
      this.containerTarget.appendChild(card)
    })
    
    // 动态加载后重新设置拖拽
    this.setupDragAndDrop()
  }

  showLoadingIndicator() {
    document.getElementById("load-more-btn")?.classList.add("hidden")
    document.getElementById("loading-indicator")?.classList.remove("hidden")
  }

  hideLoadingIndicator() {
    document.getElementById("load-more-btn")?.classList.remove("hidden")
    document.getElementById("loading-indicator")?.classList.add("hidden")
  }

  setupDragAndDrop() {
    // 只在特定账户页面启用拖拽
    if (!this.accountIdValue) {
      // 所有交易页面：禁用拖拽，移除cursor-move样式
      const items = this.containerTarget.querySelectorAll('[data-entry-id]')
      items.forEach((item) => {
        item.draggable = false
        item.classList.remove('cursor-move')
        item.style.cursor = 'default'
      })
      return
    }
    
    if (!this.dragEnabledValue) return
    
    // 特定账户页面：启用拖拽
    const items = this.containerTarget.querySelectorAll('[data-entry-id]')
    items.forEach((item) => this.removeDragHandlers(item))
    items.forEach((item) => this.addDragHandlers(item))
  }

  removeDragHandlers(item) {
    item.draggable = false
    item.removeEventListener('dragstart', this.dragStartHandler)
    item.removeEventListener('dragover', this.dragOverHandler)
    item.removeEventListener('drop', this.dropHandler)
    item.removeEventListener('dragend', this.dragEndHandler)
  }

  addDragHandlers(item) {
    item.draggable = true
    item.addEventListener('dragstart', this.dragStartHandler)
    item.addEventListener('dragover', this.dragOverHandler)
    item.addEventListener('drop', this.dropHandler)
    item.addEventListener('dragend', this.dragEndHandler)
  }

  handleDragStart(event) {
    this.draggedItem = event.currentTarget
    event.dataTransfer.effectAllowed = 'move'
    this.draggedItem.classList.add('opacity-50')
  }

  handleDragOver(event) {
    event.preventDefault()
    const target = event.currentTarget
    if (!target || target === this.draggedItem) return

    const draggedDate = this.draggedItem.dataset.date
    const targetDate = target.dataset.date
    if (draggedDate !== targetDate) {
      this.showToast('只能调整同一天的交易顺序', 'error')
      return
    }

    const bounding = target.getBoundingClientRect()
    const offset = event.clientY - bounding.top
    target.classList.toggle('border-t-2', offset < bounding.height / 2)
    target.classList.toggle('border-b-2', offset >= bounding.height / 2)
    target.classList.add('border-blue-500')
  }

  handleDrop(event) {
    event.preventDefault()
    const target = event.currentTarget
    if (!target || target === this.draggedItem) return

    const draggedDate = this.draggedItem.dataset.date
    const targetDate = target.dataset.date
    if (draggedDate !== targetDate) {
      this.showToast('只能调整同一天的交易顺序', 'error')
      this.clearDragStyles()
      return
    }

    const bounding = target.getBoundingClientRect()
    const offset = event.clientY - bounding.top
    const insertBefore = offset < bounding.height / 2

    if (insertBefore) {
      target.parentNode.insertBefore(this.draggedItem, target)
    } else {
      target.parentNode.insertBefore(this.draggedItem, target.nextSibling)
    }

    this.clearDragStyles()
    this.submitSortOrder(draggedDate)
  }

  handleDragEnd() {
    this.clearDragStyles()
  }

  clearDragStyles() {
    const items = this.containerTarget.querySelectorAll('[data-entry-id]')
    items.forEach((item) => {
      item.classList.remove('opacity-50', 'border-t-2', 'border-b-2', 'border-blue-500')
    })
  }

  getOrderedEntryIds(date) {
    return Array.from(this.containerTarget.querySelectorAll(`[data-entry-id][data-date="${date}"]`)).map((item) => item.dataset.entryId)
  }

  submitSortOrder(date) {
    if (!this.accountIdValue) return

    fetch(`/accounts/${this.accountIdValue}/reorder_entries`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify({
        entry_ids: this.getOrderedEntryIds(date),
        date: date
      })
    })
      .then((response) => response.json())
      .then((data) => {
        if (data.success) {
          this.updateBalances(data.balances)
          this.showToast('排序已保存', 'success')
        } else {
          this.showToast(data.error || '保存失败', 'error')
        }
      })
      .catch((err) => {
        console.error('排序保存失败：', err)
        this.showToast('网络错误，请重试', 'error')
      })
  }

  updateBalances(balances) {
    balances.forEach(({ entry_id, balance_after }) => {
      const item = this.containerTarget.querySelector(`[data-entry-id="${entry_id}"]`)
      const balanceField = item?.querySelector('[data-field="balance"]')
      if (balanceField) {
        balanceField.textContent = `余额: ${balance_after}`
      }
    })
  }

  showToast(message, type = 'info') {
    const toast = document.createElement('div')
    toast.className = `fixed top-4 right-4 px-4 py-2 rounded-lg z-50 ${type === 'success' ? 'bg-green-500 text-white' : type === 'error' ? 'bg-red-500 text-white' : 'bg-surface dark:bg-surface-dark text-primary'}`
    toast.textContent = message
    document.body.appendChild(toast)
    setTimeout(() => toast.remove(), 2500)
  }
}
