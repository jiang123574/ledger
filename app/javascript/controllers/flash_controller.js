import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // 3秒后自动消失
    setTimeout(() => {
      this.dismiss()
    }, 3000)
  }

  dismiss() {
    this.element.style.transition = 'opacity 0.3s ease-out'
    this.element.style.opacity = '0'
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}