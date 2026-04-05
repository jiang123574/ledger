import { Controller } from "@hotwired/stimulus"
import { getChartJs, hexToRgba, getCssColor } from "controllers/utils/chartjs_helper"

// 分类月度对比表 + 图表联动交互
// 点击表格行 → 下方折线图高亮该分类的年度趋势
export default class extends Controller {
  static values = {
    categories: Object
  }

  connect() {
    this._chart = null
    this._selectedRow = null

    // 使用事件委托，避免给每行单独绑定事件（防止内存泄漏）
    this._boundRowClick = this._handleRowClick.bind(this)
    this.element.addEventListener('click', this._boundRowClick)

    // 监听筛选变化，联动更新趋势图
    this._boundFilterChange = (e) => {
      if (e.target.matches('[data-tab-filter]')) {
        // 筛选变化时，更新趋势图为选中分类的汇总
        setTimeout(() => this._renderSummaryChart(), 50)
      }
    }
    this.element.addEventListener('change', this._boundFilterChange)

    // 切换图表显示
    const toggleCheckbox = document.getElementById('toggle-comparison-chart')
    if (toggleCheckbox) {
      this._boundToggleChange = (e) => {
        const chartArea = document.getElementById('comparison-chart-area')
        if (chartArea) {
          chartArea.classList.toggle('hidden', !e.target.checked)
          if (e.target.checked) {
            setTimeout(() => {
              const firstRow = this.element.querySelector('.comparison-row:not(.hidden)')
              if (firstRow) this.selectRow(firstRow)
              else this._renderSummaryChart()
            }, 100)
          }
        }
      }
      toggleCheckbox.addEventListener('change', this._boundToggleChange)
      // 默认展开图表区域
      if (toggleCheckbox.checked) {
        setTimeout(() => {
          const chartArea = document.getElementById('comparison-chart-area')
          if (chartArea) chartArea.classList.remove('hidden')
          // 自动选中第一行
          const firstRow = this.element.querySelector('.comparison-row:not(.hidden)')
          if (firstRow) this.selectRow(firstRow)
          else this._renderSummaryChart()
        }, 100)
      }
    }
  }

  _handleRowClick(e) {
    const row = e.target.closest('.comparison-row')
    if (row) this.selectRow(row)
  }

  // 供 report-tabs 面板切换后调用
  refresh() {
    if (this._chart) {
      this._chart.resize()
    } else {
      const firstRow = this.element.querySelector('.comparison-row:not(.hidden)')
      if (firstRow) this.selectRow(firstRow)
      else this._renderSummaryChart()
    }
  }

  // 获取当前可见（未被筛选隐藏）的分类 ID
  _getVisibleCategoryIds() {
    return [...this.element.querySelectorAll('.comparison-row:not(.hidden)')]
      .map(row => row.dataset.categoryId)
      .filter(Boolean)
  }

  // 获取当前筛选面板中选中的分类 ID
  _getCheckedCategoryIds() {
    const filterPopover = this.element.closest('[data-report-tabs-target="panel"]')
      ?.querySelector('[data-filter-group="comparison"]')
    if (!filterPopover) return this._getVisibleCategoryIds()
    return [...filterPopover.querySelectorAll('[data-tab-filter]:checked')]
      .map(cb => cb.value)
  }

  // 汇总趋势图：显示当前选中分类的月度收支汇总
  _renderSummaryChart() {
    const checkedIds = this._getCheckedCategoryIds()
    const nameEl = document.getElementById('selected-category-name')
    if (nameEl) nameEl.textContent = `已选 ${checkedIds.length} 个分类`

    // 分别汇总支出和收入
    const expenseMonthly = Array.from({ length: 12 }, () => 0)
    const incomeMonthly = Array.from({ length: 12 }, () => 0)

    checkedIds.forEach(id => {
      const cat = this.categoriesValue[id]
      if (!cat) return
      for (let m = 1; m <= 12; m++) {
        const val = cat.monthly[m] || 0
        if (cat.kind === 'income') {
          incomeMonthly[m - 1] += val
        } else {
          expenseMonthly[m - 1] += val
        }
      }
    })

    this._renderDualLineChart(expenseMonthly, incomeMonthly)
  }

  // 双线折线图：支出 + 收入
  async _renderDualLineChart(expenseData, incomeData) {
    const canvas = document.getElementById('comparison-line-chart')
    if (!canvas) return

    const Chart = await getChartJs()
    if (!Chart) return

    const ctx = canvas.getContext('2d')
    if (this._chart) this._chart.destroy()

    const months = Array.from({ length: 12 }, (_, i) => `${i + 1}月`)
    const maxVal = Math.max(...expenseData, ...incomeData, 100)

    const isDark = document.documentElement.classList.contains("dark")
    const textColor = isDark ? "#f8f9fa" : "#1a1a1a"
    const gridColor = isDark ? "#374151" : "#e9ecef"
    const expenseColor = getCssColor('--color-expense', '#ef4444')
    const incomeColor = getCssColor('--color-income', '#22c55e')

    this._chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: months,
        datasets: [
          {
            label: '支出',
            data: expenseData,
            borderColor: expenseColor,
            backgroundColor: hexToRgba(expenseColor, 0.1),
            borderWidth: 2.5,
            pointRadius: 3,
            pointHoverRadius: 5,
            pointBackgroundColor: expenseColor,
            fill: true,
            tension: 0.3
          },
          {
            label: '收入',
            data: incomeData,
            borderColor: incomeColor,
            backgroundColor: hexToRgba(incomeColor, 0.1),
            borderWidth: 2.5,
            pointRadius: 3,
            pointHoverRadius: 5,
            pointBackgroundColor: incomeColor,
            fill: true,
            tension: 0.3
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { intersect: false, mode: 'index' },
        plugins: {
          legend: {
            display: true,
            position: 'top',
            labels: { color: textColor, font: { size: 11 }, boxWidth: 12, padding: 16 }
          },
          tooltip: {
            callbacks: {
              label: (ctx) => `${ctx.dataset.label}: ¥${ctx.parsed.y.toLocaleString('zh-CN', { minimumFractionDigits: 2 })}`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: textColor, font: { size: 11 } }
          },
          y: {
            beginAtZero: true,
            max: maxVal * 1.15,
            grid: { color: gridColor },
            ticks: {
              color: textColor,
              font: { size: 11 },
              callback: (v) => v >= 1000 ? (v / 1000).toFixed(1) + 'k' : v.toString()
            }
          }
        }
      }
    })
  }

  selectRow(row) {
    // 清除之前行的单元格高亮
    if (this._selectedRow) {
      this._selectedRow.classList.remove('bg-surface-inset', 'dark:bg-surface-dark-inset', 'ring-1', 'ring-blue-500/30')
      this._selectedRow.querySelectorAll('.monthly-cell .h-0\\.5, .monthly-cell .h-1').forEach(el => {
        el.classList.remove('!opacity-100', '!h-1.5')
      })
    }

    // 高亮当前行
    row.classList.add('bg-surface-inset', 'dark:bg-surface-dark-inset', 'ring-1', 'ring-blue-500/30')
    this._selectedRow = row

    const categoryId = row.dataset.categoryId
    const catData = this.categoriesValue[categoryId]
    if (!catData) return

    // 更新标题名称（带收支标签）
    const nameEl = document.getElementById('selected-category-name')
    if (nameEl) {
      const kindLabel = catData.kind === 'income' ? '【收入】' : '【支出】'
      nameEl.textContent = kindLabel + catData.name
    }

    // 更新/创建折线图
    this.renderLineChart(catData)

    // 高亮对应行的所有单元格
    row.querySelectorAll('.monthly-cell').forEach(cell => {
      cell.querySelector('.h-0\\.5, .h-1')?.classList.add('!opacity-100', '!h-1.5')
    })
  }

  async renderLineChart(catData) {
    const canvas = document.getElementById('comparison-line-chart')
    if (!canvas) return

    const Chart = await getChartJs()
    if (!Chart) return

    const ctx = canvas.getContext('2d')

    if (this._chart) {
      this._chart.destroy()
    }

    const months = Array.from({ length: 12 }, (_, i) => `${i + 1}月`)
    const data = Array.from({ length: 12 }, (_, i) => catData.monthly[i + 1] || 0)

    // 找到最大值用于缩放
    const maxVal = Math.max(...data, 100)

    const isDark = document.documentElement.classList.contains("dark")
    const textColor = isDark ? "#f8f9fa" : "#1a1a1a"
    const gridColor = isDark ? "#374151" : "#e9ecef"

    // 从 CSS 变量读取颜色（根据收支类型选择颜色）
    const isIncome = catData.kind === 'income'
    const color = getCssColor(isIncome ? '--color-income' : '--color-expense', isIncome ? '#22c55e' : '#ef4444')

    this._chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: months,
        datasets: [{
          label: catData.name,
          data: data,
          borderColor: color,
          backgroundColor: hexToRgba(color, 0.15),
          borderWidth: 2.5,
          pointRadius: 4,
          pointHoverRadius: 6,
          pointBackgroundColor: color,
          fill: true,
          tension: 0.3
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { intersect: false, mode: 'index' },
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => `¥${ctx.parsed.y.toLocaleString('zh-CN', { minimumFractionDigits: 2 })}`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: textColor, font: { size: 11 } }
          },
          y: {
            beginAtZero: true,
            max: maxVal * 1.15,
            grid: { color: gridColor },
            ticks: {
              color: textColor,
              font: { size: 11 },
              callback: (v) => v >= 1000 ? (v / 1000).toFixed(1) + 'k' : v.toString()
            }
          }
        }
      }
    })
  }

  disconnect() {
    if (this._boundRowClick) {
      this.element.removeEventListener('click', this._boundRowClick)
      this._boundRowClick = null
    }
    if (this._boundFilterChange) {
      this.element.removeEventListener('change', this._boundFilterChange)
      this._boundFilterChange = null
    }
    if (this._boundToggleChange) {
      const toggleCheckbox = document.getElementById('toggle-comparison-chart')
      if (toggleCheckbox) {
        toggleCheckbox.removeEventListener('change', this._boundToggleChange)
      }
      this._boundToggleChange = null
    }
    if (this._chart) {
      this._chart.destroy()
      this._chart = null
    }
    this._selectedRow = null
  }
}
