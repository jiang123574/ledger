import { Controller } from "@hotwired/stimulus"

// 模块级：只注册一次，不受 Turbo 导航影响
let _navActiveHandlerRegistered = false

// 导航后更新导航栏的选中状态（sidebar + mobile bottom nav）
function updateNavActiveState() {
  const currentPath = window.location.pathname

  // 更新 sidebar 导航
  document.querySelectorAll('#desktop-sidebar nav [data-nav-path]').forEach(link => {
    const navPath = link.getAttribute('data-nav-path')
    const isActive = currentPath === navPath ||
      (navPath !== '/' && currentPath.startsWith(navPath + '/'))

    const indicator = link.querySelector('.absolute.left-0')
    const iconContainer = link.querySelector('.w-8.h-8')
    const textSpan = link.querySelector('span.text-sm')

    if (isActive) {
      link.classList.remove('text-secondary', 'hover:text-primary', 'hover:bg-surface-hover')
      link.classList.add('bg-surface', 'text-primary')
      if (indicator) indicator.classList.remove('hidden')
      if (iconContainer) {
        iconContainer.classList.remove('bg-gray-100', 'dark:bg-surface-dark-inset')
        iconContainer.classList.add('bg-gray-200', 'dark:bg-surface-dark-hover')
      }
      if (textSpan) textSpan.classList.remove('text-secondary')
      if (textSpan) textSpan.classList.add('text-primary')
      link.setAttribute('aria-current', 'page')
    } else {
      link.classList.remove('bg-surface', 'text-primary')
      link.classList.add('text-secondary', 'hover:text-primary', 'hover:bg-surface-hover')
      if (indicator) indicator.classList.add('hidden')
      if (iconContainer) {
        iconContainer.classList.remove('bg-gray-200', 'dark:bg-surface-dark-hover')
        iconContainer.classList.add('bg-gray-100', 'dark:bg-surface-dark-inset')
      }
      if (textSpan) textSpan.classList.remove('text-primary')
      if (textSpan) textSpan.classList.add('text-secondary')
      link.removeAttribute('aria-current')
    }
  })

  // 更新底部导航
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
 * Handles bottom nav active state and keyboard shortcuts
 */
export default class extends Controller {
  connect() {
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

  handleKeydown(e) {
    if (e.key === 'Escape') {
      // 关闭可见的弹窗
      const modals = document.querySelectorAll('.fixed.inset-0:not(.hidden)')
      if (modals.length > 0) {
        modals[modals.length - 1].classList.add('hidden')
      }
    }
  }
}
