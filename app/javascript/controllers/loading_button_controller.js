import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]
  static values = { loadingText: String }

  showLoading() {
    if (!this.hasButtonTarget) return

    this.buttonTarget.disabled = true
    this.buttonTarget.setAttribute("aria-disabled", "true")
    this.buttonTarget.setAttribute("aria-busy", "true")
    const text = this.loadingTextValue || "Loading..."

    this.buttonTarget.innerHTML = `
      <span class="inline-flex items-center gap-2">
        <span class="btn-spinner" aria-hidden="true"></span>
        <span>${text}</span>
      </span>
    `
  }
}
