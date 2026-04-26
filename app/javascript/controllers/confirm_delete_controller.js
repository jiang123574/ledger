import { Controller } from "@hotwired/stimulus"

// 确认删除控制器
// 用于处理隐藏表单 + button onclick 模式
// 使用方式：
//   <button type="button"
//           data-controller="confirm-delete"
//           data-action="click->confirm-delete#confirm"
//           data-confirm-delete-form-id-value="delete-form-123"
//           data-confirm-delete-title-value="确认删除"
//           data-confirm-delete-content-value="确定删除此记录吗？">
//     删除
//   </button>
//   <form id="delete-form-123" method="post" action="..." style="display:none">...</form>

export default class extends Controller {
  static values = {
    formId: String,
    title: { type: String, default: "确认删除" },
    content: { type: String, default: "确定删除此记录吗？" },
    confirmText: { type: String, default: "删除" },
    cancelText: { type: String, default: "取消" }
  }

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
        danger: true
      }).then(confirmed => {
        if (confirmed) {
          this.submitForm()
        }
      })
    } else {
      // fallback
      if (window.confirm(this.contentValue)) {
        this.submitForm()
      }
    }
  }

  submitForm() {
    const form = document.getElementById(this.formIdValue)
    if (form) {
      form.submit()
    }
  }
}