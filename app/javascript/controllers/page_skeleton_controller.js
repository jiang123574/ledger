import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    this.hide = this.hide.bind(this)
    document.addEventListener("turbo:load", this.hide)
    requestAnimationFrame(this.hide)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.hide)
  }

  hide() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("page-skeleton-hidden")
    }
  }
}
