import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "billWrapper", "transactionList", "summaryBar", "filterBar",
    "dateBtn", "billBtn"
  ]

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
    if (this.modeValue === "bill") {
      this.billWrapperTarget?.classList.remove("hidden")
      this.transactionListTarget?.classList.add("hidden")
      this.summaryBarTarget?.classList.add("hidden")
      this.filterBarTarget?.classList.add("hidden")
      this.dateBtnTarget?.classList.remove("bg-blue-500", "text-white", "font-medium", "shadow-xs")
      this.dateBtnTarget?.classList.add("text-secondary", "dark:text-secondary-dark", "hover:bg-surface-hover")
      this.billBtnTarget?.classList.add("bg-blue-500", "text-white", "font-medium", "shadow-xs")
      this.billBtnTarget?.classList.remove("text-secondary", "dark:text-secondary-dark", "hover:bg-surface-hover")
    } else {
      this.billWrapperTarget?.classList.add("hidden")
      this.transactionListTarget?.classList.remove("hidden")
      this.summaryBarTarget?.classList.remove("hidden")
      this.filterBarTarget?.classList.remove("hidden")
      this.dateBtnTarget?.classList.add("bg-blue-500", "text-white", "font-medium", "shadow-xs")
      this.dateBtnTarget?.classList.remove("text-secondary", "dark:text-secondary-dark", "hover:bg-surface-hover")
      this.billBtnTarget?.classList.remove("bg-blue-500", "text-white", "font-medium", "shadow-xs")
      this.billBtnTarget?.classList.add("text-secondary", "dark:text-secondary-dark", "hover:bg-surface-hover")
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