import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["creditCardFields", "dueDayModeSelect", "dueDayFixed", "dueDayRelative"]

  connect() {
    this.toggleCreditCardFields()
    this.toggleDueDayMode()
    this.bindTypeChange()
  }

  bindTypeChange() {
    const typeSelect = this.element.querySelector('[name="account[type]"]')
    if (typeSelect) {
      typeSelect.addEventListener("change", () => this.toggleCreditCardFields())
    }
  }

  toggleCreditCardFields() {
    const typeSelect = this.element.querySelector('[name="account[type]"]')
    if (!typeSelect || !this.hasCreditCardFieldsTarget) return

    const isCreditCard = typeSelect.value === "CREDIT"
    this.creditCardFieldsTarget.classList.toggle("hidden", !isCreditCard)
  }

  toggleDueDayMode() {
    if (!this.hasDueDayModeSelectTarget || !this.hasDueDayFixedTarget || !this.hasDueDayRelativeTarget) return

    const mode = this.dueDayModeSelectTarget.value
    this.dueDayFixedTarget.classList.toggle("hidden", mode !== "fixed")
    this.dueDayRelativeTarget.classList.toggle("hidden", mode !== "relative")
  }
}
