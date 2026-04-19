import { Controller } from "@hotwired/stimulus"

// 模块级：只注册一次，不受 Turbo 导航影响
let _navClickHandlerRegistered = false
let _navActiveHandlerRegistered = false

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

// 导航后更新侧边栏/底部栏的选中状态
function updateNavActiveState() {
  const currentPath = window.location.pathname

  // 侧边栏 nav items (桌面 + 移动端)
  document.querySelectorAll('[data-nav-path]').forEach(link => {
    const navPath = link.getAttribute('data-nav-path')
    // 精确匹配或子路径匹配
    const isActive = currentPath === navPath ||
      (navPath !== '/' && currentPath.startsWith(navPath + '/'))

    // 更新链接样式
    if (isActive) {
      link.classList.remove('text-secondary', 'hover:bg-surface-hover', 'hover:text-primary')
      link.classList.add('bg-surface', 'text-primary')
    } else {
      link.classList.remove('bg-surface', 'text-primary')
      link.classList.add('text-secondary', 'hover:bg-surface-hover', 'hover:text-primary')
    }

    // 更新指示器（左侧竖条）
    const wrapper = link.closest('.relative.group')
    if (wrapper) {
      const indicator = wrapper.querySelector('.absolute.left-0')
      if (isActive && !indicator) {
        const bar = document.createElement('div')
        bar.className = 'absolute left-0 w-1 h-6 bg-inverse rounded-r'
        wrapper.querySelector('a')?.prepend(bar)
      } else if (!isActive && indicator) {
        indicator.remove()
      }
    }

    // 更新图标容器
    const iconDiv = link.querySelector('.w-8.h-8')
    if (iconDiv) {
      if (isActive) {
        iconDiv.classList.remove('bg-gray-100', 'dark:bg-surface-dark-inset')
        iconDiv.classList.add('bg-gray-200', 'dark:bg-surface-dark-hover', 'text-primary', 'dark:text-primary-dark')
      } else {
        iconDiv.classList.remove('bg-gray-200', 'dark:bg-surface-dark-hover', 'text-primary', 'dark:text-primary-dark')
        iconDiv.classList.add('bg-gray-100', 'dark:bg-surface-dark-inset')
      }
    }

    // 更新文字颜色
    const textSpan = link.querySelector('span.text-sm')
    if (textSpan) {
      if (isActive) {
        textSpan.classList.remove('text-secondary')
        textSpan.classList.add('text-primary')
      } else {
        textSpan.classList.remove('text-primary')
        textSpan.classList.add('text-secondary')
      }
    }

    // 更新 aria-current
    if (isActive) {
      link.setAttribute('aria-current', 'page')
    } else {
      link.removeAttribute('aria-current')
    }
  })

  // 底部导航栏（特殊样式：蓝色）
  document.querySelectorAll('#mobile-bottom-nav [data-nav-path]').forEach(link => {
    const navPath = link.getAttribute('data-nav-path')
    const isActive = currentPath === navPath ||
      (navPath !== '/' && currentPath.startsWith(navPath + '/'))

    if (isActive) {
      link.classList.remove('text-secondary', 'hover:text-primary', 'hover:bg-surface-hover')
      link.classList.add('text-blue-600', 'bg-blue-50')
      link.setAttribute('aria-current', 'page')
    } else {
      link.classList.remove('text-blue-600', 'bg-blue-50')
      link.classList.add('text-secondary', 'hover:text-primary', 'hover:bg-surface-hover')
      link.removeAttribute('aria-current')
    }
  })
}

function ensureNavActiveHandler() {
  if (_navActiveHandlerRegistered) return
  _navActiveHandlerRegistered = true

  document.addEventListener('turbo:load', updateNavActiveState)
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
    ensureNavActiveHandler()
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
