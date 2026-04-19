import { Controller } from "@hotwired/stimulus"

// 模块级：只注册一次，不受 Turbo 导航影响
let _navClickHandlerRegistered = false

function ensureNavClickHandler() {
  if (_navClickHandlerRegistered) return
  _navClickHandlerRegistered = true

  document.addEventListener('click', (e) => {
    const sidebar = document.getElementById('mobile-sidebar')
    if (!sidebar || sidebar.classList.contains('-translate-x-full')) return

    const link = e.target.closest('#mobile-sidebar a[href]')
    if (!link) return

    // 关闭侧边栏（直接操作 DOM，不依赖 Stimulus 实例）
    sidebar.classList.remove('translate-x-0')
    sidebar.classList.add('-translate-x-full')

    const overlay = document.getElementById('sidebar-overlay')
    if (overlay) {
      overlay.classList.remove('opacity-100', 'pointer-events-auto')
      overlay.classList.add('opacity-0', 'pointer-events-none')
    }
    document.body.classList.remove('overflow-hidden')
  })
}

/**
 * Mobile Layout Controller
 * Handles mobile sidebar, safe areas, and responsive interactions
 */
export default class extends Controller {
  static targets = ["sidebar", "overlay"]
  
  connect() {
    this.previousScrollY = 0
    // 页面加载/导航后始终重置侧边栏为关闭状态
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.remove('translate-x-0')
      this.sidebarTarget.classList.add('-translate-x-full')
    }
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove('opacity-100', 'pointer-events-auto')
      this.overlayTarget.classList.add('opacity-0', 'pointer-events-none')
    }
    document.body.classList.remove('overflow-hidden')

    // 注册全局 click handler（幂等）
    ensureNavClickHandler()
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
    if (this.hasSidebarTarget && !this.sidebarTarget.classList.contains('-translate-x-full')) return
    
    this.previousScrollY = window.scrollY
    
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
    if (this.hasSidebarTarget && this.sidebarTarget.classList.contains('-translate-x-full')) return
    
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
    const isVisuallyOpen = this.hasSidebarTarget && !this.sidebarTarget.classList.contains('-translate-x-full')
    if (isVisuallyOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  handleKeydown(e) {
    if (e.key === 'Escape') {
      const isVisuallyOpen = this.hasSidebarTarget && !this.sidebarTarget.classList.contains('-translate-x-full')
      if (isVisuallyOpen) this.close()
    }
  }
}
