import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amountInput", "receivableIdInput"]

  close() {
    // 隐藏整个弹窗容器（即 data-controller 所在的元素）
    this.element.classList.add('hidden')
  }

  setFullAmount() {
    const receivableId = this.receivableIdInputTarget.value
    if (!receivableId) return

    const receivablesData = this.loadDataSource('receivables-data', [])
    const receivable = receivablesData.find(r => r.id == receivableId)
    if (receivable && this.hasAmountInputTarget) {
      this.amountInputTarget.value = receivable.amount
    }
  }

  loadDataSource(id, defaultVal) {
    const el = document.getElementById(id)
    if (el && el.textContent) {
      try {
        defaultVal = JSON.parse(el.textContent)
      } catch (e) {
        console.error(`Error parsing ${id}:`, e)
      }
    }
    return defaultVal
  }
}