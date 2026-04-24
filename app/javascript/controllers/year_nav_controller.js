import { Controller } from "@hotwired/stimulus"

// 年度/月份导航控制器 - 保留当前 hash 面板状态
// 当切换年份/月份时，保持当前的面板状态（如 #assets）
export default class extends Controller {
  static targets = ["prevLink", "nextLink"]

  connect() {
    this.updateLinks()
    // 监听 hash 变化
    this._boundHashChange = () => this.updateLinks()
    window.addEventListener('hashchange', this._boundHashChange)
  }

  disconnect() {
    if (this._boundHashChange) {
      window.removeEventListener('hashchange', this._boundHashChange)
      this._boundHashChange = null
    }
  }

  updateLinks() {
    const hash = window.location.hash
    if (hash && hash !== '#trend') {
      // 更新左右导航链接，添加 hash
      if (this.hasPrevLinkTarget) {
        const prevHref = this.prevLinkTarget.getAttribute('href')
        if (prevHref && !prevHref.includes('#')) {
          this.prevLinkTarget.setAttribute('href', prevHref + hash)
        }
      }
      if (this.hasNextLinkTarget) {
        const nextHref = this.nextLinkTarget.getAttribute('href')
        if (nextHref && !nextHref.includes('#')) {
          this.nextLinkTarget.setAttribute('href', nextHref + hash)
        }
      }
    } else {
      // 回到默认面板时，移除 hash
      this.resetLinks()
    }
  }

  resetLinks() {
    if (this.hasPrevLinkTarget) {
      const prevHref = this.prevLinkTarget.getAttribute('href')
      if (prevHref) {
        this.prevLinkTarget.setAttribute('href', prevHref.split('#')[0])
      }
    }
    if (this.hasNextLinkTarget) {
      const nextHref = this.nextLinkTarget.getAttribute('href')
      if (nextHref) {
        this.nextLinkTarget.setAttribute('href', nextHref.split('#')[0])
      }
    }
  }

  // 点击导航时确保 hash 保留
  navigate(event) {
    event.preventDefault()
    const link = event.currentTarget
    let href = link.getAttribute('href')

    // 移除可能存在的旧 hash，添加当前 hash
    const basePath = href.split('#')[0]
    const currentHash = window.location.hash

    if (currentHash && currentHash !== '#trend') {
      href = basePath + currentHash
    } else {
      href = basePath
    }

    // 使用 Turbo 导航
    window.location.href = href
  }
}