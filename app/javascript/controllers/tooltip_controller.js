import { Controller } from "@hotwired/stimulus"
import { autoUpdate, computePosition, flip, offset, shift } from "@floating-ui/dom"

/**
 * Tooltip Controller - Display tooltips on hover
 *
 * Usage:
 *   <span data-controller="tooltip" data-tooltip-placement-value="top">
 *     <span data-icon>Hover me</span>
 *     <div data-tooltip-target="tooltip" class="hidden">Tooltip text</div>
 *   </span>
 *
 * Values:
 *   - placement: Position of tooltip (default: "top")
 *   - offset: Distance from trigger (default: 10)
 *   - crossAxis: Horizontal offset (default: 0)
 */
export default class extends Controller {
  static targets = ["tooltip"]
  static values = {
    placement: { type: String, default: "top" },
    offset: { type: Number, default: 10 },
    crossAxis: { type: Number, default: 0 }
  }

  connect() {
    this._cleanup = null
    this.boundUpdate = this.update.bind(this)
    this.addEventListeners()
  }

  disconnect() {
    this.removeEventListeners()
    this.stopAutoUpdate()
  }

  addEventListeners() {
    this.element.addEventListener("mouseenter", this.show)
    this.element.addEventListener("mouseleave", this.hide)
  }

  removeEventListeners() {
    this.element.removeEventListener("mouseenter", this.show)
    this.element.removeEventListener("mouseleave", this.hide)
  }

  show = () => {
    this.tooltipTarget.classList.remove("hidden")
    this.startAutoUpdate()
    this.update()
  }

  hide = () => {
    this.tooltipTarget.classList.add("hidden")
    this.stopAutoUpdate()
  }

  startAutoUpdate() {
    if (!this._cleanup) {
      const reference = this.element.querySelector("[data-icon]") || this.element
      this._cleanup = autoUpdate(
        reference,
        this.tooltipTarget,
        this.boundUpdate
      )
    }
  }

  stopAutoUpdate() {
    if (this._cleanup) {
      this._cleanup()
      this._cleanup = null
    }
  }

  update() {
    const reference = this.element.querySelector("[data-icon]") || this.element
    computePosition(
      reference,
      this.tooltipTarget,
      {
        placement: this.placementValue,
        middleware: [
          offset({
            mainAxis: this.offsetValue,
            crossAxis: this.crossAxisValue
          }),
          flip(),
          shift({ padding: 5 })
        ]
      }
    ).then(({ x, y }) => {
      Object.assign(this.tooltipTarget.style, {
        left: `${x}px`,
        top: `${y}px`
      })
    })
  }
}