import { Controller } from "@hotwired/stimulus"

// 分类筛选弹窗控制器 — 点击按钮弹出浮层，点击外部关闭
// 复用 report-tabs 的全选/反选逻辑
export default class extends Controller {
  static targets = ["panel", "count"]

  connect() {
    this._closeOnOutsideClick = this._closeOnOutsideClick.bind(this)
    this._updateCount()
  }

  disconnect() {
    document.removeEventListener("click", this._closeOnOutsideClick)
  }

  toggle(event) {
    event.stopPropagation()
    const isOpen = !this.panelTarget.classList.contains("hidden")
    if (isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.panelTarget.classList.remove("hidden")
    document.addEventListener("click", this._closeOnOutsideClick)
  }

  close() {
    this.panelTarget.classList.add("hidden")
    document.removeEventListener("click", this._closeOnOutsideClick)
  }

  _closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  selectAll(event) {
    event.preventDefault()
    event.stopPropagation()
    this._setAll(true)
  }

  deselectAll(event) {
    event.preventDefault()
    event.stopPropagation()
    this._setAll(false)
  }

  _setAll(checked) {
    const checkboxes = this.element.querySelectorAll('[data-tab-filter]')
    checkboxes.forEach(cb => { cb.checked = checked })
    this._updateCount()

    // 触发 report-tabs 的筛选逻辑
    checkboxes.forEach(cb => {
      cb.dispatchEvent(new Event("change", { bubbles: true }))
    })
  }

  _updateCount() {
    if (this.hasCountTarget) {
      const total = this.element.querySelectorAll('[data-tab-filter]').length
      const checked = this.element.querySelectorAll('[data-tab-filter]:checked').length
      this.countTarget.textContent = checked === total ? total : `${checked}/${total}`
    }
  }
}
