import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["result"]

  connect() {
    this.resultTarget.style.display = "none"
  }

  async test(event) {
    event.preventDefault()

    this.resultTarget.textContent = "测试中..."
    this.resultTarget.className = "text-sm text-secondary dark:text-secondary-dark"
    this.resultTarget.style.display = "inline"

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.element.href, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        }
      })
      const data = await response.json()

      if (data.success) {
        this.resultTarget.textContent = "✓ 连接成功"
        this.resultTarget.className = "text-sm text-green-600 dark:text-green-400"
      } else {
        this.resultTarget.textContent = `✗ ${data.error}`
        this.resultTarget.className = "text-sm text-red-600 dark:text-red-400"
      }
    } catch (error) {
      this.resultTarget.textContent = "✗ 请求失败"
      this.resultTarget.className = "text-sm text-red-600 dark:text-red-400"
    }
  }
}