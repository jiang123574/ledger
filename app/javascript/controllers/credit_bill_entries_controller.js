import { Controller } from "@hotwired/stimulus"
import { renderEntryCards, renderLoading, renderError } from "entry_card_renderer"

export default class extends Controller {
  static targets = ["container"]
  static values = {
    accountId: String,
    dragEnabled: { type: Boolean, default: true }
  }

  connect() {
    this.onRender = this.onRender.bind(this)
    this.onLoading = this.onLoading.bind(this)
    this.onError = this.onError.bind(this)

    this.dragStartHandler = this.handleDragStart.bind(this)
    this.dragOverHandler = this.handleDragOver.bind(this)
    this.dragDropHandler = this.handleDrop.bind(this)
    this.dragEndHandler = this.handleDragEnd.bind(this)

    this.element.addEventListener("credit-bill-entries:render", this.onRender)
    this.element.addEventListener("credit-bill-entries:loading", this.onLoading)
    this.element.addEventListener("credit-bill-entries:error", this.onError)
    this.element.dataset.creditBillEntriesReady = "true"
  }

  disconnect() {
    this.element.removeEventListener("credit-bill-entries:render", this.onRender)
    this.element.removeEventListener("credit-bill-entries:loading", this.onLoading)
    this.element.removeEventListener("credit-bill-entries:error", this.onError)
    delete this.element.dataset.creditBillEntriesReady

    if (this.containerTarget) {
      const items = this.containerTarget.querySelectorAll('[data-entry-id]')
      items.forEach((item) => this.removeDragHandlers(item))
    }
  }

  render(entries) {
    renderEntryCards(this.containerTarget, entries, {
      onEdit: (id) => {
        if (window.openEditTransactionModal) window.openEditTransactionModal(id)
      },
      onDelete: (id, name) => {
        if (window.confirmDeleteTransaction) window.confirmDeleteTransaction(id, name)
      },
      emptyMessage: "该期暂无交易记录",
      dragEnabled: this.dragEnabledValue && this.accountIdValue
    })

    if (this.dragEnabledValue && this.accountIdValue) {
      this.setupDragAndDrop()
    }
  }

  showLoading() {
    renderLoading(this.containerTarget)
  }

  showError(message = "加载失败") {
    renderError(this.containerTarget, { errorMessage: message })
  }

  onRender(event) {
    this.render(event.detail?.entries || [])
  }

  onLoading() {
    this.showLoading()
  }

  onError(event) {
    this.showError(event.detail?.message || "加载失败")
  }

  setupDragAndDrop() {
    const items = this.containerTarget.querySelectorAll('[data-entry-id]')
    items.forEach((item) => this.removeDragHandlers(item))
    items.forEach((item) => this.addDragHandlers(item))
  }

  removeDragHandlers(item) {
    item.draggable = false
    item.removeEventListener('dragstart', this.dragStartHandler)
    item.removeEventListener('dragover', this.dragOverHandler)
    item.removeEventListener('drop', this.dragDropHandler)
    item.removeEventListener('dragend', this.dragEndHandler)
  }

  addDragHandlers(item) {
    item.draggable = true
    item.addEventListener('dragstart', this.dragStartHandler)
    item.addEventListener('dragover', this.dragOverHandler)
    item.addEventListener('drop', this.dragDropHandler)
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
      if (!item) return
      const balanceField = item.querySelector('[data-field="balance"]')
      if (balanceField) {
        balanceField.textContent = balance_after
      }
      const mobileBalanceField = item.querySelector('[data-field="balance-mobile"]')
      if (mobileBalanceField) {
        mobileBalanceField.textContent = balance_after
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