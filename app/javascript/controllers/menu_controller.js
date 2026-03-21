import { Controller } from "@hotwired/stimulus"
import { autoUpdate, computePosition, offset, shift } from "@floating-ui/dom"

/**
 * Menu Controller - Dropdown menu with positioning
 *
 * Usage:
 *   <div data-controller="menu" data-menu-placement-value="bottom-end">
 *     <button data-menu-target="button">Toggle</button>
 *     <div data-menu-target="content" class="hidden">
 *       Menu content here
 *     </div>
 *   </div>
 *
 * Values:
 *   - placement: Position of menu (default: "bottom-end")
 *   - offset: Distance from trigger (default: 6)
 *   - mobileFullwidth: Full width on mobile (default: true)
 */
export default class extends Controller {
  static targets = ["button", "content"]
  static values = {
    placement: { type: String, default: "bottom-end" },
    offset: { type: Number, default: 6 },
    mobileFullwidth: { type: Boolean, default: true }
  }

  connect() {
    this.isOpen = false
    this.boundUpdate = this.update.bind(this)
    this.addEventListeners()
    this.startAutoUpdate()
  }

  disconnect() {
    this.removeEventListeners()
    this.stopAutoUpdate()
    this.close()
  }

  addEventListeners() {
    this.buttonTarget.addEventListener("click", this.toggle)
    this.element.addEventListener("keydown", this.handleKeydown)
    document.addEventListener("click", this.handleOutsideClick)
    document.addEventListener("turbo:load", this.handleTurboLoad)
  }

  removeEventListeners() {
    this.buttonTarget.removeEventListener("click", this.toggle)
    this.element.removeEventListener("keydown", this.handleKeydown)
    document.removeEventListener("click", this.handleOutsideClick)
    document.removeEventListener("turbo:load", this.handleTurboLoad)
  }

  handleTurboLoad = () => {
    if (!this.isOpen) this.close()
  }

  handleOutsideClick = (event) => {
    if (this.isOpen && !this.element.contains(event.target)) {
      this.close()
    }
  }

  handleKeydown = (event) => {
    if (event.key === "Escape") {
      this.close()
      this.buttonTarget.focus()
    }
  }

  toggle = () => {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.isOpen = true
    this.contentTarget.classList.remove("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.update()
    this.focusFirstElement()
  }

  close() {
    this.isOpen = false
    this.contentTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  focusFirstElement() {
    const focusableElements = 'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    const firstFocusable = this.contentTarget.querySelectorAll(focusableElements)[0]
    if (firstFocusable) {
      firstFocusable.focus({ preventScroll: true })
    }
  }

  startAutoUpdate() {
    if (!this._cleanup && this.buttonTarget && this.contentTarget) {
      this._cleanup = autoUpdate(
        this.buttonTarget,
        this.contentTarget,
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
    if (!this.buttonTarget || !this.contentTarget) return

    const isSmallScreen = !window.matchMedia("(min-width: 768px)").matches
    const useMobileFullwidth = isSmallScreen && this.mobileFullwidthValue

    computePosition(
      this.buttonTarget,
      this.contentTarget,
      {
        placement: useMobileFullwidth ? "bottom" : this.placementValue,
        middleware: [
          offset(this.offsetValue),
          shift({ padding: 5 })
        ],
        strategy: "fixed"
      }
    ).then(({ x, y }) => {
      if (useMobileFullwidth) {
        Object.assign(this.contentTarget.style, {
          position: "fixed",
          left: "0px",
          width: "100vw",
          top: `${y}px`
        })
      } else {
        Object.assign(this.contentTarget.style, {
          position: "fixed",
          left: `${x}px`,
          top: `${y}px`,
          width: ""
        })
      }
    })
  }
}