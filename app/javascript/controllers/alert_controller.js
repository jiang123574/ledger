import { Controller } from "@hotwired/stimulus"

/**
 * Alert Controller - Dismissible alerts
 *
 * Usage:
 *   <div data-controller="alert--dismissible" class="...">
 *     Alert message
 *     <button data-action="alert--dismissible#dismiss">×</button>
 *   </div>
 */
export default class extends Controller {
  dismiss() {
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-10px)"

    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}