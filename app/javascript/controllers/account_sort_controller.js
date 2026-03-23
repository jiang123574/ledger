import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { updateUrl: String }

  start(event) {
    event.dataTransfer.setData("text/plain", event.target.dataset.accountId)
    event.target.classList.add("opacity-50")
    this.draggedElement = event.target
  }

  over(event) {
    event.preventDefault()
    const target = event.target.closest("[data-account-id]")
    if (target && target !== this.draggedElement) {
      target.classList.add("border-t-2", "border-blue-500")
    }
  }

  drop(event) {
    event.preventDefault()
    const target = event.target.closest("[data-account-id]")
    if (target && target !== this.draggedElement) {
      const draggedId = event.dataTransfer.getData("text/plain")
      const targetId = target.dataset.accountId
      
      // 交换位置
      this.updateOrder(draggedId, targetId)
      
      // 视觉上交换
      const draggedElement = this.draggedElement
      const parent = draggedElement.parentNode
      parent.insertBefore(draggedElement, target)
    }
    target?.classList.remove("border-t-2", "border-blue-500")
  }

  end(event) {
    event.target.classList.remove("opacity-50")
    document.querySelectorAll(".border-blue-500").forEach(el => {
      el.classList.remove("border-t-2", "border-blue-500")
    })
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
}