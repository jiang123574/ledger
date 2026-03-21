import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // 添加进入动画
    this.element.classList.add("page-fade-enter")
    setTimeout(() => {
      this.element.classList.remove("page-fade-enter")
    }, 200)
  }

  disconnect() {
    // 清理
    this.element.classList.remove("page-fade-enter", "page-fade-leave")
  }
}