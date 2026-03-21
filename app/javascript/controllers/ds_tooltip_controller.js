import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    placement: String,
    offset: Number
  }

  connect() {
    this.boundMouseEnter = this.handleMouseEnter.bind(this)
    this.boundMouseLeave = this.handleMouseLeave.bind(this)
    
    this.element.addEventListener("mouseenter", this.boundMouseEnter)
    this.element.addEventListener("mouseleave", this.boundMouseLeave)
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.boundMouseEnter)
    this.element.removeEventListener("mouseleave", this.boundMouseLeave)
  }

  handleMouseEnter() {
    const tooltip = this.tooltipTarget
    if (!tooltip) return

    tooltip.classList.remove("hidden")
    
    const rect = this.element.getBoundingClientRect()
    const tooltipRect = tooltip.getBoundingClientRect()
    
    let top, left
    
    switch (this.placementValue || "top") {
      case "top":
        top = rect.top - tooltipRect.height - this.offsetValue
        left = rect.left + (rect.width - tooltipRect.width) / 2
        break
      case "bottom":
        top = rect.bottom + this.offsetValue
        left = rect.left + (rect.width - tooltipRect.width) / 2
        break
      case "left":
        top = rect.top + (rect.height - tooltipRect.height) / 2
        left = rect.left - tooltipRect.width - this.offsetValue
        break
      case "right":
        top = rect.top + (rect.height - tooltipRect.height) / 2
        left = rect.right + this.offsetValue
        break
    }
    
    tooltip.style.top = `${top}px`
    tooltip.style.left = `${left}px`
    tooltip.classList.remove("opacity-0")
    tooltip.classList.add("opacity-100")
  }

  handleMouseLeave() {
    const tooltip = this.tooltipTarget
    if (!tooltip) return
    
    tooltip.classList.add("opacity-0")
    tooltip.classList.remove("opacity-100")
    setTimeout(() => {
      tooltip.classList.add("hidden")
    }, 200)
  }

  get tooltipTarget() {
    return this.element.querySelector("[data-ds-tooltip-target='tooltip']")
  }
}
