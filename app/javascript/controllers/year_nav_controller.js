import { Controller } from "@hotwired/stimulus"

// 年度/月份导航控制器 - 保留当前面板状态和分类筛选状态
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

  // 获取当前面板的选中分类 ID
  getSelectedCategoryIds() {
    const panel = this.getCurrentPanel()
    // 根据面板名称找到对应的筛选组
    const filterGroupMap = {
      'category-stats': 'category-stats',
      'expense': 'expense',
      'income': 'income',
      'comparison': 'comparison'
    }
    const filterGroup = filterGroupMap[panel]
    if (!filterGroup) return []

    // 从 hiddenCheckbox 获取选中状态
    const filterWrapper = document.querySelector(`[data-filter-group="${filterGroup}"]`)
    if (!filterWrapper) return []

    return [...filterWrapper.querySelectorAll('[data-tab-filter]:checked')]
      .map(cb => cb.value)
      .filter(id => id)
  }

  updateLinks() {
    const panel = this.getCurrentPanel()
    const categoryIds = this.getSelectedCategoryIds()

    // 更新左右导航链接，添加 panel 和 category_ids 参数
    if (this.hasPrevLinkTarget) {
      const prevHref = this.prevLinkTarget.getAttribute('href')
      if (prevHref) {
        this.prevLinkTarget.setAttribute('href', this.buildUrl(prevHref, panel, categoryIds))
      }
    }
    if (this.hasNextLinkTarget) {
      const nextHref = this.nextLinkTarget.getAttribute('href')
      if (nextHref) {
        this.nextLinkTarget.setAttribute('href', this.buildUrl(nextHref, panel, categoryIds))
      }
    }
  }

  buildUrl(href, panel, categoryIds) {
    // 移除已有的参数，添加新的
    const [path, existingQuery] = href.split('?')
    const params = new URLSearchParams(existingQuery || '')
    params.delete('panel')
    params.delete('category_ids[]')

    if (panel && panel !== 'trend') {
      params.set('panel', panel)
    }
    categoryIds.forEach(id => params.append('category_ids[]', id))

    const queryString = params.toString()
    return queryString ? `${path}?${queryString}` : path
  }
}