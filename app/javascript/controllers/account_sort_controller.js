import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { updateUrl: String }

  connect() {
    this.draggedElement = null
    this.placeholderElement = null // 记录当前 placeholder 目标，避免全局查找
    this._boundDragOver = this.over.bind(this)
    this._boundDrop = this.drop.bind(this)
    this._boundDragEnd = this.end.bind(this)
  }

  start(event) {
    event.dataTransfer.setData("text/plain", event.target.dataset.accountId)
    event.dataTransfer.effectAllowed = "move"
    this.draggedElement = event.target

    // 拖拽时禁用 transition 避免动画延迟
    this.draggedElement.style.transition = "none"
    this.draggedElement.classList.add("opacity-50")

    // 绑定一次性事件到 document（比逐元素绑定更高效）
    document.addEventListener("dragover", this._boundDragOver, { passive: false })
    document.addEventListener("drop", this._boundDrop, { passive: false })
    document.addEventListener("dragend", this._boundDragEnd)
  }

  over(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"

    const target = event.target.closest("[data-account-id]")
    if (!target || target === this.draggedElement) return

    // 先清除上一次的 placeholder
    this._clearPlaceholder()

    // 在目标位置显示 placeholder（只操作一个元素）
    target.classList.add("border-t-2", "border-blue-500")
    this.placeholderElement = target
  }

  drop(event) {
    event.preventDefault()
    event.stopPropagation()

    const target = event.target.closest("[data-account-id]")
    if (target && target !== this.draggedElement) {
      const draggedId = event.dataTransfer.getData("text/plain")
      const targetId = target.dataset.accountId

      // 视觉上先交换（立即生效，不等 API）
      const parent = this.draggedElement.parentNode
      parent.insertBefore(this.draggedElement, target)

      // 异步发送 API（不阻塞 UI）
      this.updateOrder(draggedId, targetId)
    }

    this._cleanup()
  }

  end(event) {
    if (this.draggedElement) {
      this.draggedElement.classList.remove("opacity-50")
      // 恢复 transition（延迟一帧确保 drop 的 insertBefore 已完成）
      requestAnimationFrame(() => {
        if (this.draggedElement) this.draggedElement.style.transition = ""
      })
    }
    this._clearPlaceholder()
    this._unbindEvents()
    this.draggedElement = null
  }

  // 内部方法：只清除已记录的 placeholder 元素，不做全局查询
  _clearPlaceholder() {
    if (this.placeholderElement) {
      this.placeholderElement.classList.remove("border-t-2", "border-blue-500")
      this.placeholderElement = null
    }
  }

  _unbindEvents() {
    document.removeEventListener("dragover", this._boundDragOver)
    document.removeEventListener("drop", this._boundDrop)
    document.removeEventListener("dragend", this._boundDragEnd)
  }

  _cleanup() {
    this._clearPlaceholder()
    this._unbindEvents()
  }

  updateOrder(draggedId, targetId) {
    fetch(`/accounts/${draggedId}/reorder`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
      },
      body: JSON.stringify({ target_id: targetId })
    }).catch(err => console.error('Failed to update order:', err))
  }

  disconnect() {
    this._cleanup()
  }
}
