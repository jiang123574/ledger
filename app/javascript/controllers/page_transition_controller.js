import { Controller } from "@hotwired/stimulus"

// 模块级变量：标记是否是首次加载
let isFirstLoad = true

export default class extends Controller {
  connect() {
    // 只在首次加载时添加动画，Turbo 导航时不触发
    if (isFirstLoad) {
      isFirstLoad = false
      this.element.classList.add("page-enter-animate")

      setTimeout(() => {
        this.element.classList.remove("page-enter-animate")
      }, 150)
    }
  }
}
