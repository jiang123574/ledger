import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const items = Array.from(this.element.children)
    items.forEach((item, index) => {
      item.classList.add("stagger-item")
      item.style.setProperty("--stagger-index", index)
    })
  }
}
