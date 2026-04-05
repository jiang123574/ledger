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

    // 切换图表显示
    const toggleCheckbox = document.getElementById('toggle-comparison-chart')
    if (toggleCheckbox) {
      this._boundToggleChange = (e) => {
        const chartArea = document.getElementById('comparison-chart-area')
        if (chartArea) {
          chartArea.classList.toggle('hidden', !e.target.checked)
        }
      }
      toggleCheckbox.addEventListener('change', this._boundToggleChange)
      // 默认展开图表区域
      if (toggleCheckbox.checked) {
        setTimeout(() => {
          const chartArea = document.getElementById('comparison-chart-area')
          if (chartArea) chartArea.classList.remove('hidden')
          // 自动选中第一行
          const firstRow = this.element.querySelector('.comparison-row')
          if (firstRow) this.selectRow(firstRow)
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
      // 如果还没初始化图表，尝试选中第一行触发渲染
      const firstRow = this.element.querySelector('.comparison-row')
      if (firstRow) this.selectRow(firstRow)
    }
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

    // 更新标题名称
    const nameEl = document.getElementById('selected-category-name')
    if (nameEl) { nameEl.textContent = catData.name }

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

    // 从 CSS 变量读取颜色（暗色模式自动适配）
    const expenseColor = getCssColor('--color-expense', '#ef4444')

    this._chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: months,
        datasets: [{
          label: catData.name,
          data: data,
          borderColor: expenseColor,
          backgroundColor: hexToRgba(expenseColor, 0.15),
          borderWidth: 2.5,
          pointRadius: 4,
          pointHoverRadius: 6,
          pointBackgroundColor: expenseColor,
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
    // 清理事件委托
    if (this._boundRowClick) {
      this.element.removeEventListener('click', this._boundRowClick)
      this._boundRowClick = null
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
