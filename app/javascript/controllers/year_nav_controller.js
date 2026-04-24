import { Controller } from "@hotwired/stimulus"

// 年度/月份导航控制器 - 保留当前面板状态
// hash 是用户当前交互状态（最新），URL params 是服务器渲染的初始状态
export default class extends Controller {
  static targets = ["prevLink", "nextLink"]

  connect() {
    // 监听 hash 变化（用户点击左侧导航切换面板）
    this._boundHashChange = () => this.updateLinks()
    window.addEventListener('hashchange', this._boundHashChange)

    // 初始化时更新链接
    this.updateLinks()
  }

  disconnect() {
    if (this._boundHashChange) {
      window.removeEventListener('hashchange', this._boundHashChange)
      this._boundHashChange = null
    }
  }

  getCurrentPanel() {
    // 优先从 hash 读取（用户当前交互状态，最新）
    const hash = window.location.hash.replace('#', '')
    if (hash) return hash

    // 其次从 URL 的 panel 参数读取（服务器渲染的初始状态）
    const urlParams = new URLSearchParams(window.location.search)
    const panelParam = urlParams.get('panel')
    if (panelParam) return panelParam

    // 默认
    return 'trend'
  }

  updateLinks() {
    const panel = this.getCurrentPanel()

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