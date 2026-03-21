import { Controller } from "@hotwired/stimulus"

/**
 * Select Controller - Custom dropdown select
 *
 * Usage:
 *   <div data-controller="select">
 *     <input type="hidden" data-select-target="input" name="selected">
 *     <button data-select-target="button" data-action="click->select#toggle">
 *       Select an option
 *     </button>
 *     <div data-select-target="menu" class="hidden">
 *       <div data-action="click->select#select" data-value="1">Option 1</div>
 *       <div data-action="click->select#select" data-value="2">Option 2</div>
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["button", "menu", "input"]
  static values = {
    placement: { type: String, default: "bottom-start" },
    offset: { type: Number, default: 6 }
  }

  connect() {
    this.isOpen = false
    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    this.boundKeydown = this.handleKeydown.bind(this)

    document.addEventListener("click", this.boundOutsideClick)
    this.element.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
    this.element.removeEventListener("keydown", this.boundKeydown)
  }

  toggle = () => {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.isOpen = true
    this.menuTarget.classList.remove("hidden", "opacity-0", "-translate-y-1")
    this.menuTarget.classList.add("opacity-100", "translate-y-0")
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.scrollToSelected()
  }

  close() {
    this.isOpen = false
    this.menuTarget.classList.remove("opacity-100", "translate-y-0")
    this.menuTarget.classList.add("opacity-0", "-translate-y-1")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    setTimeout(() => {
      if (!this.isOpen && this.hasMenuTarget) {
        this.menuTarget.classList.add("hidden")
      }
    }, 150)
  }

  select(event) {
    const selectedElement = event.currentTarget
    const value = selectedElement.dataset.value
    const label = selectedElement.dataset.filterName || selectedElement.textContent.trim()

    // Update button text
    this.buttonTarget.textContent = label

    // Update hidden input
    if (this.hasInputTarget) {
      this.inputTarget.value = value
      this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }

    // Update selected state visually
    const previousSelected = this.menuTarget.querySelector("[aria-selected='true']")
    if (previousSelected) {
      previousSelected.setAttribute("aria-selected", "false")
      previousSelected.classList.remove("bg-gray-100")
    }

    selectedElement.setAttribute("aria-selected", "true")
    selectedElement.classList.add("bg-gray-100")

    // Dispatch custom event
    this.element.dispatchEvent(new CustomEvent("dropdown:select", {
      detail: { value, label },
      bubbles: true
    }))

    this.close()
    this.buttonTarget.focus()
  }

  scrollToSelected() {
    const selected = this.menuTarget.querySelector("[aria-selected='true']")
    if (selected) {
      selected.scrollIntoView({ block: "center" })
    }
  }

  handleOutsideClick(event) {
    if (this.isOpen && !this.element.contains(event.target)) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (!this.isOpen) return

    if (event.key === "Escape") {
      this.close()
      this.buttonTarget.focus()
    }

    if (event.key === "Enter" && event.target.dataset.value) {
      event.preventDefault()
      event.target.click()
    }
  }
}