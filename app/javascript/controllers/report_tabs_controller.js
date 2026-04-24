import { Controller } from "@hotwired/stimulus"

// 报表标签页控制器 — 左侧侧边栏导航（仿设置页风格）+ 分类筛选联动
export default class extends Controller {
  static targets = ["navItem", "panel"]

  static values = {
    activePanel: { type: String, default: "trend" }
  }

  connect() {
    // 从 URL hash 恢复 tab（如 #assets、#comparison）
    const hash = window.location.hash.replace('#', '')
    if (hash && this.panelTargets.some(p => p.dataset.panelName === hash)) {
      this.activePanelValue = hash
    } else {
      // 如果没有 hash，从 DOM 状态恢复（服务器可能已通过 panel 参数设置）
      this.syncFromDOM()
    }

    this.showActive()

    // 监听 Turbo Frame 加载完成事件（frame 刷新后重新同步状态）
    this._boundFrameLoad = () => this.onFrameLoad()
    document.addEventListener('turbo:frame-load', this._boundFrameLoad)

    // 绑定分类筛选（事件委托）
    this._boundFilterChange = (e) => {
      if (e.target.matches('[data-tab-filter]')) this.onFilterChange(e.target)
    }
    this.element.addEventListener('change', this._boundFilterChange)
  }

  onFrameLoad() {
    // Turbo Frame 刷新后，同步面板状态
    this.syncFromDOM()
    this.showActive()
  }

  syncFromDOM() {
    // 从 DOM 中找出当前可见的面板（服务器渲染的状态）
    const visiblePanel = this.panelTargets.find(p => !p.classList.contains('hidden'))
    if (visiblePanel && visiblePanel.dataset.panelName) {
      this.activePanelValue = visiblePanel.dataset.panelName
    }
  }

  switchPanel(e) {
    e.preventDefault()
    const panelId = e.currentTarget.dataset.panelId
    this.activePanelValue = panelId

    // 更新 URL hash，不触发滚动
    history.replaceState(null, '', '#' + panelId)

    this.showActive()
  }

  showActive() {
    // 导航高亮
    this.navItemTargets.forEach(item => {
      const isActive = item.dataset.panelId === this.activePanelValue
      item.classList.toggle('active', isActive)
      item.setAttribute('aria-current', isActive ? 'page' : 'false')
    })

    // 面板切换
    this.panelTargets.forEach(panel => {
      const isActive = panel.dataset.panelName === this.activePanelValue
      panel.classList.toggle('hidden', !isActive)
      if (isActive) {
        // 延迟触发 Chart.js 的 refresh/resize
        setTimeout(() => {
          window.dispatchEvent(new Event('resize'))
          // 唤醒 panel 本身及子元素的 controllers
          const elementsToCheck = [panel, ...panel.querySelectorAll('[data-controller]')]
          elementsToCheck.forEach(el => {
            const identifiers = el.dataset.controller?.split(' ') || []
            identifiers.forEach(id => {
              const ctrl = this.application.getControllerForElementAndIdentifier(el, id)
              if (ctrl && typeof ctrl.refresh === 'function') {
                ctrl.refresh()
              }
            })
          })
        }, 60)
      }
    })
  }

  onFilterChange(checkbox) {
    const panelEl = checkbox.closest('[data-report-tabs-target="panel"]')
    if (!panelEl) return
    this.applyFilter(panelEl.dataset.panelName)
  }

  applyFilter(panelName) {
    const panel = this.panelTargets.find(p => p.dataset.panelName === panelName)
    if (!panel) return
    const checkedIds = [...panel.querySelectorAll('[data-tab-filter]:checked')].map(el => el.value)

    switch (panelName) {
      case 'expense':
        this.toggleRows(panel, '#expense-category-list [data-category-row]', checkedIds)
        break
      case 'income':
        this.toggleRows(panel, '#income-category-list [data-income-row]', checkedIds)
        break
      case 'comparison':
        panel.querySelectorAll('.comparison-row').forEach(row => {
          row.classList.toggle('hidden', checkedIds.length > 0 && !checkedIds.includes(row.dataset.categoryId || ''))
        })
        break
    }
  }

  toggleRows(panel, selector, checkedIds) {
    panel.querySelectorAll(selector).forEach(row => {
      row.classList.toggle('hidden', checkedIds.length > 0 && !checkedIds.includes(row.dataset.categoryId || ''))
    })
  }

  setFilterGroup(group, checked) {
    this.element.querySelectorAll(`[data-filter-group="${group}"][data-tab-filter]`).forEach(cb => { cb.checked = checked })
    // 找到包含该组的 panel 并应用过滤
    const wrapper = this.element.querySelector(`[data-filter-group="${group}"]`)
    const panel = wrapper?.closest('[data-report-tabs-target="panel"]')
    if (panel) this.applyFilter(panel.dataset.panelName)
  }

  disconnect() {
    if (this._boundFilterChange) {
      this.element.removeEventListener('change', this._boundFilterChange)
      this._boundFilterChange = null
    }
    if (this._boundFrameLoad) {
      document.removeEventListener('turbo:frame-load', this._boundFrameLoad)
      this._boundFrameLoad = null
    }
  }
}
