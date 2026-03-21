import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "summary"]
  static values = {
    open: Boolean,
    animated: { type: Boolean, default: true }
  }

  connect() {
    this.isOpen = this.openValue
    this.updateDisplay({ animate: false })
  }

  toggle() {
    this.isOpen = !this.isOpen
    this.updateDisplay()
  }

  show() {
    this.isOpen = true
    this.updateDisplay()
  }

  hide() {
    this.isOpen = false
    this.updateDisplay()
  }

  updateDisplay(options = {}) {
    const animate = options.animate ?? this.animatedValue
    const content = this.contentTarget
    const summary = this.summaryTarget

    if (!content) return

    if (this.isOpen) {
      if (animate) {
        content.style.maxHeight = "0"
        content.style.overflow = "hidden"
        content.style.transition = "max-height 0.3s ease-out"
        requestAnimationFrame(() => {
          content.style.maxHeight = content.scrollHeight + "px"
        })
      } else {
        content.style.maxHeight = "none"
        content.style.overflow = ""
      }
      summary?.classList.add("open")
    } else {
      if (animate) {
        content.style.maxHeight = content.scrollHeight + "px"
        requestAnimationFrame(() => {
          content.style.maxHeight = "0"
        })
      } else {
        content.style.maxHeight = "0"
        content.style.overflow = "hidden"
      }
      summary?.classList.remove("open")
    }
  }
}
