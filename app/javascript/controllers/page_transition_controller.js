import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.playEnterAnimation()
    
    document.addEventListener("turbo:before-render", this.beforeRender.bind(this))
    document.addEventListener("turbo:render", this.onRender.bind(this))
  }

  disconnect() {
    document.removeEventListener("turbo:before-render", this.beforeRender)
    document.removeEventListener("turbo:render", this.onRender)
  }

  beforeRender(event) {
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(16px)"
  }

  onRender(event) {
    this.playEnterAnimation()
  }

  playEnterAnimation() {
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(16px)"
    
    requestAnimationFrame(() => {
      this.element.style.transition = "opacity 0.3s ease-out, transform 0.3s ease-out"
      this.element.style.opacity = "1"
      this.element.style.transform = "translateY(0)"
    })
  }
}