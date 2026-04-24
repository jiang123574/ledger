import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dateBtn", "billBtn"]

  static values = {
    mode: { type: String, default: "date" }
  }

  connect() {
    const params = new URLSearchParams(window.location.search)
    this.modeValue = params.get("view_mode") || "date"
    this.updateUI()
  }

  switchTo(event) {
    const mode = event.currentTarget.dataset.mode
    this.modeValue = mode
    this.updateUI()
    this.updateURL()

    if (mode === "bill" && window.initCreditBills) {
      window.initCreditBills()
    }
  }

  updateUI() {
    // 这些元素不在 controller 元素内部，需要用 document.getElementById 查找
    const billWrapper = document.getElementById('credit-bill-wrapper')
    const transactionList = document.getElementById('transaction-list')
    const summaryBar = document.getElementById('summary-bar')
    const filterBar = document.getElementById('filter-bar')

    if (this.modeValue === "bill") {
      if (billWrapper) billWrapper.classList.remove("hidden")
      if (transactionList) transactionList.classList.add("hidden")
      if (summaryBar) summaryBar.classList.add("hidden")
      if (filterBar) filterBar.classList.add("hidden")
      if (this.hasDateBtnTarget) {
        this.dateBtnTarget.classList.remove("bg-blue-500", "text-white", "font-medium", "shadow-xs")
        this.dateBtnTarget.classList.add("text-secondary", "dark:text-secondary-dark", "hover:bg-surface-hover")
      }
      if (this.hasBillBtnTarget) {
        this.billBtnTarget.classList.add("bg-blue-500", "text-white", "font-medium", "shadow-xs")
        this.billBtnTarget.classList.remove("text-secondary", "dark:text-secondary-dark", "hover:bg-surface-hover")
      }
    } else {
      if (billWrapper) billWrapper.classList.add("hidden")
      if (transactionList) transactionList.classList.remove("hidden")
      if (summaryBar) summaryBar.classList.remove("hidden")
      if (filterBar) filterBar.classList.remove("hidden")
      if (this.hasDateBtnTarget) {
        this.dateBtnTarget.classList.add("bg-blue-500", "text-white", "font-medium", "shadow-xs")
        this.dateBtnTarget.classList.remove("text-secondary", "dark:text-secondary-dark", "hover:bg-surface-hover")
      }
      if (this.hasBillBtnTarget) {
        this.billBtnTarget.classList.remove("bg-blue-500", "text-white", "font-medium", "shadow-xs")
        this.billBtnTarget.classList.add("text-secondary", "dark:text-secondary-dark", "hover:bg-surface-hover")
      }
    }
  }

  updateURL() {
    const params = new URLSearchParams(window.location.search)
    if (this.modeValue === "bill") {
      params.set("view_mode", "bill")
    } else {
      params.delete("view_mode")
    }
    const newUrl = window.location.pathname + (params.toString() ? "?" + params.toString() : "")
    history.replaceState({ mode: this.modeValue }, "", newUrl)
  }
}