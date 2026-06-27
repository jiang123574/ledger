import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "input", "diff"]

  static values = {
    accountId: Number,
    availableCredit: Number
  }

  connect() {
    this.lastValue = this.inputTarget.value
    this.skipNextSave = false
  }

  edit() {
    this.lastValue = this.inputTarget.value
    this.displayTarget.classList.add("hidden")
    this.inputTarget.classList.remove("hidden")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  cancel() {
    this.inputTarget.value = this.lastValue
    this.inputTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
  }

  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.inputTarget.blur()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.skipNextSave = true
      this.cancel()
      this.inputTarget.blur()
    }
  }

  save() {
    if (this.skipNextSave) {
      this.skipNextSave = false
      return
    }

    const value = this.inputTarget.value.trim()
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    this.inputTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")

    fetch(`/accounts/${this.accountIdValue}/update_actual_credit`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ actual_available_credit: value })
    })
      .then(response => response.json())
      .then(data => this.updateDisplay(data.actual_available_credit))
      .catch(() => {
        // 失败时静默处理，保持显示原值
      })
  }

  updateDisplay(saved) {
    if (saved === null || saved === undefined || saved === "") {
      this.lastValue = ""
      this.inputTarget.value = ""
      this.displayTarget.textContent = "点击输入"
      this.diffTarget.classList.add("hidden")
      this.diffTarget.textContent = ""
      return
    }

    const num = parseFloat(saved)
    this.lastValue = saved.toString()
    this.inputTarget.value = this.lastValue
    this.displayTarget.textContent = this.formatCurrency(num)

    const diff = num - this.availableCreditValue
    const diffAbs = this.formatCurrency(Math.abs(diff))
    const sign = diff >= 0 ? "+" : "-"
    this.diffTarget.textContent = `差额 ${sign}${diffAbs}`
    this.diffTarget.className = `px-1.5 py-0.5 rounded-full border text-xs ${this.diffClasses(diff)}`
    this.diffTarget.classList.remove("hidden")
  }

  formatCurrency(value) {
    return new Intl.NumberFormat("zh-CN", { style: "currency", currency: "CNY" }).format(value)
  }

  diffClasses(diff) {
    if (diff >= 0) {
      return "bg-green-50 text-green-700 border-green-200 dark:bg-green-900/20 dark:text-green-400 dark:border-green-800"
    }

    return "bg-red-50 text-red-600 border-red-200 dark:bg-red-900/20 dark:text-red-400 dark:border-red-800"
  }
}
