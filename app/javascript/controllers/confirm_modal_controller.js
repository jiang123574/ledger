import { Controller } from "@hotwired/stimulus"

// 通用确认弹窗控制器
// 支持自定义标题、内容、确认/取消按钮文字
// 提供 Promise 接口，方便在其他控制器中使用

export default class extends Controller {
  static targets = ["modal", "title", "content", "confirmBtn", "cancelBtn"]
  static values = {
    title: { type: String, default: "确认操作" },
    content: String,
    confirmText: { type: String, default: "确认" },
    cancelText: { type: String, default: "取消" },
    confirmClass: { type: String, default: "bg-red-600 text-white hover:bg-red-700" },
    danger: { type: Boolean, default: false }
  }

  connect() {
    // 暴露全局方法供其他地方使用
    window.showConfirmDialog = this.show.bind(this)
    window.closeConfirmDialog = this.close.bind(this)
  }

  disconnect() {
    window.showConfirmDialog = undefined
    window.closeConfirmDialog = undefined
  }

  // 显示确认弹窗，返回 Promise
  // resolve(true) = 确认, resolve(false) = 取消
  show(options = {}) {
    return new Promise((resolve) => {
      this._resolvePromise = resolve

      // 设置内容
      const title = options.title || this.titleValue
      const content = options.content || this.contentValue
      const confirmText = options.confirmText || this.confirmTextValue
      const cancelText = options.cancelText || this.cancelTextValue
      const danger = options.danger || this.dangerValue
      const confirmClass = options.confirmClass || this.confirmClassValue

      if (this.hasTitleTarget) this.titleTarget.textContent = title
      if (this.hasContentTarget) this.contentTarget.innerHTML = content
      if (this.hasConfirmBtnTarget) {
        this.confirmBtnTarget.textContent = confirmText
        // 更新按钮样式
        this.confirmBtnTarget.className = `px-4 py-2 text-sm font-medium rounded-lg transition-smooth ${confirmClass}`
        if (danger) {
          this.confirmBtnTarget.className = "px-4 py-2 text-sm font-medium rounded-lg bg-red-600 text-white hover:bg-red-700 transition-smooth"
        }
      }
      if (this.hasCancelBtnTarget) this.cancelBtnTarget.textContent = cancelText

      // 显示弹窗
      if (this.hasModalTarget) this.modalTarget.classList.remove("hidden")
    })
  }

  // 确认按钮点击
  confirm() {
    this.close()
    if (this._resolvePromise) {
      this._resolvePromise(true)
      this._resolvePromise = null
    }
  }

  // 取消按钮点击
  cancel() {
    this.close()
    if (this._resolvePromise) {
      this._resolvePromise(false)
      this._resolvePromise = null
    }
  }

  // 关闭弹窗
  close() {
    if (this.hasModalTarget) this.modalTarget.classList.add("hidden")
    // 重置按钮状态
    if (this.hasConfirmBtnTarget) {
      this.confirmBtnTarget.textContent = this.confirmTextValue
      this.confirmBtnTarget.disabled = false
    }
  }

  // 点击背景关闭
  closeOnBackground(event) {
    if (event.target === this.modalTarget || event.target.classList.contains("modal-overlay-bg")) {
      this.cancel()
    }
  }
}