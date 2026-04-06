import { Controller } from "@hotwired/stimulus"
import { formatMoney, formatCurrencyRaw } from "bill_formatters"

export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    this.onRender = this.onRender.bind(this)
    this.onLoading = this.onLoading.bind(this)
    this.onError = this.onError.bind(this)

    this.element.addEventListener("credit-bill-entries:render", this.onRender)
    this.element.addEventListener("credit-bill-entries:loading", this.onLoading)
    this.element.addEventListener("credit-bill-entries:error", this.onError)
    this.element.dataset.creditBillEntriesReady = "true"
  }

  disconnect() {
    this.element.removeEventListener("credit-bill-entries:render", this.onRender)
    this.element.removeEventListener("credit-bill-entries:loading", this.onLoading)
    this.element.removeEventListener("credit-bill-entries:error", this.onError)
    delete this.element.dataset.creditBillEntriesReady
  }

  render(entries) {
    if (!entries || entries.length === 0) {
      this.showEmpty("该期暂无交易记录")
      return
    }

    this.containerTarget.innerHTML = ""
    entries.forEach((entry) => {
      const row = this.templateTarget.content.firstElementChild.cloneNode(true)

      const typeBadgeClass = this.typeBadgeClass(entry.display_type)
      const amountClass = this.amountClass(entry.display_amount_type)
      const amountText = formatMoney(Math.abs(entry.display_amount || 0))

      row.querySelector('[data-field="date"]').textContent = entry.date || ""
      row.querySelector('[data-field="type"]').textContent = entry.display_type || ""
      row.querySelector('[data-field="type"]').className =
        `inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${typeBadgeClass}`
      row.querySelector('[data-field="name"]').textContent = entry.display_name || "-"
      row.querySelector('[data-field="note"]').textContent = entry.note || ""
      row.querySelector('[data-field="amount"]').textContent = amountText
      row.querySelector('[data-field="amount"]').className = `text-sm font-medium ${amountClass}`
      row.querySelector('[data-field="balance"]').textContent = `余额: ${formatCurrencyRaw(entry.balance_after)}`

      const editButton = row.querySelector('[data-role="edit"]')
      const deleteButton = row.querySelector('[data-role="delete"]')
      if (editButton) {
        editButton.addEventListener("click", () => {
          if (window.openEditTransactionModal) window.openEditTransactionModal(entry.id)
        })
      }
      if (deleteButton) {
        deleteButton.addEventListener("click", () => {
          if (window.confirmDeleteTransaction) {
            window.confirmDeleteTransaction(entry.id, entry.display_name || "")
          }
        })
      }

      this.containerTarget.appendChild(row)
    })
  }

  showLoading() {
    this.renderStatus("p-4 text-center text-secondary dark:text-secondary-dark text-sm", "加载中...")
  }

  showError(message = "加载失败") {
    this.renderStatus("p-4 text-center text-red-500 text-sm", message)
  }

  showEmpty(message = "暂无数据") {
    this.renderStatus("p-8 text-center text-secondary dark:text-secondary-dark text-sm", message)
  }

  typeBadgeClass(displayType) {
    if (displayType === "收入" || displayType === "转入") return "bg-income-light text-income"
    if (displayType === "支出" || displayType === "转出") return "bg-expense-light text-expense"
    if (displayType === "转账") return "bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300"
    return "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300"
  }

  amountClass(displayAmountType) {
    return displayAmountType === "INCOME" ? "text-income" : "text-expense"
  }

  renderStatus(className, message) {
    this.containerTarget.innerHTML = ""
    const node = document.createElement("div")
    node.className = className
    node.textContent = message || ""
    this.containerTarget.appendChild(node)
  }

  onRender(event) {
    this.render(event.detail?.entries || [])
  }

  onLoading() {
    this.showLoading()
  }

  onError(event) {
    this.showError(event.detail?.message || "加载失败")
  }
}
