import { Controller } from "@hotwired/stimulus"

// 年度/月份导航控制器 - 保留当前面板状态
// 使用 Turbo Frame 局部刷新，将 hash 转换为 panel 参数发送到服务器
export default class extends Controller {
  static targets = ["prevLink", "nextLink"]

  connect() {
    // 初始化时更新链接
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
    const hash = window.location.hash.replace('#', '')
    const panel = hash || 'trend'

    // 更新左右导航链接，添加 panel 参数
    if (this.hasPrevLinkTarget) {
      const prevHref = this.prevLinkTarget.getAttribute('href')
      if (prevHref) {
        this.prevLinkTarget.setAttribute('href', this.addPanelParam(prevHref, panel))
      }
    }
    if (this.hasNextLinkTarget) {
      const nextHref = this.nextLinkTarget.getAttribute('href')
      if (nextHref) {
        this.nextLinkTarget.setAttribute('href', this.addPanelParam(nextHref, panel))
      }
    }
  }

  addPanelParam(href, panel) {
    // 移除已有的 panel 参数，添加新的
    const [path, existingQuery] = href.split('?')
    const params = new URLSearchParams(existingQuery || '')
    params.delete('panel')
    if (panel && panel !== 'trend') {
      params.set('panel', panel)
    }
    const queryString = params.toString()
    return queryString ? `${path}?${queryString}` : path
  }
}