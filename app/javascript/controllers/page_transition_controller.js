import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.classList.add("page-enter-animate")
    
    setTimeout(() => {
      this.element.classList.remove("page-enter-animate")
    }, 150)
  }
}