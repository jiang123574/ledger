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
    }

    this.showActive()

    // 绑定分类筛选
    this.element.querySelectorAll('[data-tab-filter]').forEach(checkbox => {
      checkbox.addEventListener('change', () => this.onFilterChange(checkbox))
    })
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
          // 唤醒 hidden 面板中的 chart controllers（asset-trend-chart / category-comparison）
          panel.querySelectorAll('[data-controller]').forEach(el => {
            const identifiers = el.dataset.controller.split(' ')
            for (const id of identifiers) {
              const ctrl = this.application.getControllerForElementAndIdentifier(el, id)
              if (ctrl && typeof ctrl.refresh === 'function') {
                ctrl.refresh()
                break
              }
            }
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
}
