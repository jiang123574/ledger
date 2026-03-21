import { Controller } from "@hotwired/stimulus"

/**
 * Mobile Layout Controller
 * Handles mobile sidebar, safe areas, and responsive interactions
 */
export default class extends Controller {
  static targets = ["sidebar", "overlay"]
  
  connect() {
    this.isOpen = false
    this.previousScrollY = 0
    this.bindEvents()
  }

  disconnect() {
    this.unbindEvents()
  }

  bindEvents() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.boundHandleKeydown)
  }

  unbindEvents() {
    if (this.boundHandleKeydown) {
      document.removeEventListener('keydown', this.boundHandleKeydown)
    }
  }

  open() {
    if (this.isOpen) return
    
    this.previousScrollY = window.scrollY
    this.isOpen = true
    
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.remove('-translate-x-full')
      this.sidebarTarget.classList.add('translate-x-0')
    }
    
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove('opacity-0', 'pointer-events-none')
      this.overlayTarget.classList.add('opacity-100', 'pointer-events-auto')
    }
    
    document.body.classList.add('overflow-hidden')
  }

  close() {
    if (!this.isOpen) return
    
    this.isOpen = false
    
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.remove('translate-x-0')
      this.sidebarTarget.classList.add('-translate-x-full')
    }
    
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove('opacity-100', 'pointer-events-auto')
      this.overlayTarget.classList.add('opacity-0', 'pointer-events-none')
    }
    
    document.body.classList.remove('overflow-hidden')
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  handleKeydown(e) {
    if (e.key === 'Escape' && this.isOpen) {
      this.close()
    }
  }
}