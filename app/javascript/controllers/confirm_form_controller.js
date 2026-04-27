import { Controller } from "@hotwired/stimulus"

// 通用确认表单控制器
// 合并了原 confirm-delete 和 confirm-submit 控制器的功能
//
// 使用方式：
// 1. 指定 formId（适用于隐藏表单 + button 模式）:
//    <button data-controller="confirm-form"
//            data-action="click->confirm-form#confirm"
//            data-confirm-form-form-id-value="delete-form-123"
//            data-confirm-form-title-value="确认删除">
//      删除
//    </button>
//    <form id="delete-form-123" style="display:none">...</form>
//
// 2. 自动查找关联表单（适用于 button_to 或 form 内的 button）:
//    <form data-controller="confirm-form" data-action="submit->confirm-form#confirm">
//      ...
//    </form>
//    或
//    <%= button_to "...", data: { controller: "confirm-form", action: "click->confirm-form#confirm" } %>

export default class extends Controller {
  static values = {
    formId: String,
    title: { type: String, default: "确认操作" },
    content: { type: String, default: "确定要执行此操作吗？" },
    confirmText: { type: String, default: "确认" },
    cancelText: { type: String, default: "取消" },
    danger: { type: Boolean, default: false }
  }

  confirm(event) {
    event.preventDefault()
    event.stopPropagation()

    if (window.showConfirmDialog) {
      window.showConfirmDialog({
        title: this.titleValue,
        content: this.contentValue,
        confirmText: this.confirmTextValue,
        cancelText: this.cancelTextValue,
        danger: this.dangerValue
      }).then(confirmed => {
        if (confirmed) {
          this.submitForm()
        }
      })
    } else {
      if (window.confirm(this.contentValue)) {
        this.submitForm()
      }
    }
  }

  submitForm() {
    // 优先使用 formId 查找表单
    if (this.formIdValue) {
      const form = document.getElementById(this.formIdValue)
      if (form) {
        form.submit()
        return
      }
    }

    // 自动查找关联表单
    if (this.element.tagName === 'FORM') {
      this.element.submit()
    } else {
      const form = this.element.closest('form')
      if (form) {
        form.submit()
      } else {
        // button_to 创建的隐藏表单
        const action = this.element.dataset.action || this.element.formAction
        if (action) {
          const hiddenForm = document.querySelector(`form[action="${action}"]`)
          if (hiddenForm) {
            hiddenForm.submit()
          }
        }
      }
    }
  }
}