import { Controller } from "@hotwired/stimulus"

// 确认后提交控制器
// 用于替换 inline onclick confirm() 模式
// 使用方式：在 button_to 或 form 上添加 data-controller="confirm-submit"
//          并设置 data-confirm-submit-title-value, data-confirm-submit-content-value 等属性

export default class extends Controller {
  static values = {
    title: { type: String, default: "确认操作" },
    content: { type: String, default: "确定要执行此操作吗？" },
    confirmText: { type: String, default: "确认" },
    cancelText: { type: String, default: "取消" },
    danger: { type: Boolean, default: false }
  }

  // 拦截表单提交，显示确认弹窗
  confirm(event) {
    event.preventDefault()
    event.stopPropagation()

    // 使用全局确认弹窗
    if (window.showConfirmDialog) {
      window.showConfirmDialog({
        title: this.titleValue,
        content: this.contentValue,
        confirmText: this.confirmTextValue,
        cancelText: this.cancelTextValue,
        danger: this.dangerValue
      }).then(confirmed => {
        if (confirmed) {
          // 确认后提交表单
          this.submitForm()
        }
      })
    } else {
      // fallback: 如果全局弹窗未加载，使用原生 confirm
      if (window.confirm(this.contentValue)) {
        this.submitForm()
      }
    }
  }

  submitForm() {
    // 如果元素是 form，直接提交
    if (this.element.tagName === 'FORM') {
      this.element.submit()
    } else {
      // 如果是 button，查找关联的表单或创建一个
      const form = this.element.closest('form')
      if (form) {
        form.submit()
      } else {
        // button_to 创建的隐藏表单
        const hiddenForm = document.querySelector(`form[action="${this.element.dataset.action || this.element.formAction}"]`)
        if (hiddenForm) {
          hiddenForm.submit()
        }
      }
    }
  }
}