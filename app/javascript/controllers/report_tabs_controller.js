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
    const hash = window.location.hash.replace('#', '')
    if (hash && this.panelTargets.some(p => p.dataset.panelName === hash)) {
      this.activePanelValue = hash
    } else {
      this.syncFromDOM()
    }
    this.showActive()

    // 根据当前面板的 hiddenCheckbox 状态执行筛选，并更新 URL hash
    if (this.activePanelValue && this.activePanelValue !== 'trend') {
      this.applyFilter(this.activePanelValue)
      history.replaceState(null, '', '#' + this.activePanelValue)
    }
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
        // 筛选后重新计算总计
        this.updateComparisonTotals(panel)
        break
    }
  }

  // 更新 comparison 面板的总计（根据可见的分类行）
  updateComparisonTotals(panel) {
    const visibleRows = panel.querySelectorAll('.comparison-row:not(.hidden)')

    // 初始化月度总计
    const monthlyExpense = Array(12).fill(0)
    const monthlyIncome = Array(12).fill(0)
    let totalExpense = 0
    let totalIncome = 0

    // 遍历可见行，累加金额
    visibleRows.forEach(row => {
      const kind = row.dataset.categoryKind
      const total = parseFloat(row.dataset.categoryTotal) || 0
      const monthlyValues = JSON.parse(row.dataset.monthlyValues || '{}')

      if (kind === 'expense') {
        totalExpense += total
        for (let m = 1; m <= 12; m++) {
          monthlyExpense[m - 1] += parseFloat(monthlyValues[m]) || 0
        }
      } else if (kind === 'income') {
        totalIncome += total
        for (let m = 1; m <= 12; m++) {
          monthlyIncome[m - 1] += parseFloat(monthlyValues[m]) || 0
        }
      }
    })

    // 更新支出总计行
    const expenseRow = panel.querySelector('[data-comparison-totals="expense"]')
    if (expenseRow) {
      expenseRow.querySelector('[data-total="expense-total"]').textContent = this.formatCurrency(totalExpense)
      for (let m = 1; m <= 12; m++) {
        expenseRow.querySelector(`[data-total="expense-${m}"]`).textContent = this.formatCurrency(monthlyExpense[m - 1])
      }
    }

    // 更新收入总计行
    const incomeRow = panel.querySelector('[data-comparison-totals="income"]')
    if (incomeRow) {
      incomeRow.querySelector('[data-total="income-total"]').textContent = this.formatCurrency(totalIncome)
      for (let m = 1; m <= 12; m++) {
        incomeRow.querySelector(`[data-total="income-${m}"]`).textContent = this.formatCurrency(monthlyIncome[m - 1])
      }
    }

    // 更新差额行
    const diffRow = panel.querySelector('[data-comparison-totals="diff"]')
    if (diffRow) {
      const totalDiff = totalIncome - totalExpense
      const totalCell = diffRow.querySelector('[data-total="diff-total"]')
      totalCell.textContent = this.formatCurrency(totalDiff)
      this.updateDiffCellClass(totalCell, totalDiff)

      for (let m = 1; m <= 12; m++) {
        const monthDiff = monthlyIncome[m - 1] - monthlyExpense[m - 1]
        const monthCell = diffRow.querySelector(`[data-total="diff-${m}"]`)
        monthCell.textContent = this.formatCurrency(monthDiff)
        this.updateDiffCellClass(monthCell, monthDiff)
      }
    }
  }

  // 格式化货币（简单版，与 Rails format_currency 保持一致）
  formatCurrency(amount) {
    const absAmount = Math.abs(amount)
    const formatted = absAmount.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    return amount < 0 ? `-¥${formatted}` : `¥${formatted}`
  }

  // 更新差额单元格的颜色类
  updateDiffCellClass(cell, value) {
    const positiveClass = cell.dataset.classPositive || 'text-income'
    const negativeClass = cell.dataset.classNegative || 'text-expense'
    cell.classList.remove(positiveClass, negativeClass)
    cell.classList.add(value >= 0 ? positiveClass : negativeClass)
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
