import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "content"]

  connect() {
    this.setupClickOutsideListener()
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside)
  }

  toggle() {
    this.contentTarget.classList.toggle("hidden")
  }

  show() {
    this.contentTarget.classList.remove("hidden")
  }

  hide() {
    this.contentTarget.classList.add("hidden")
  }

  setupClickOutsideListener() {
    this.handleClickOutside = (event) => {
      if (!this.element.contains(event.target)) {
        this.hide()
      }
    }
    document.addEventListener("click", this.handleClickOutside)
  }
}
