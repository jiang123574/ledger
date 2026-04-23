import { Controller } from "@hotwired/stimulus"
import { getChartJs, hexToRgba } from "controllers/utils/chartjs_helper"

export default class extends Controller {
  static targets = [
    "periodType", "periodValue", "periodNav",
    "customDateRange", "startDate", "endDate",
    "categoryCheckbox",
    "incomeTotal", "incomeBarChart", "incomeBarCanvas", "incomeDonutChart", "incomeDonutCanvas", "incomeEmpty",
    "expenseTotal", "expenseBarChart", "expenseBarCanvas", "expenseDonutChart", "expenseDonutCanvas", "expenseEmpty"
  ]

  static values = {
    year: Number,
    month: Number,
    startDate: String,
    endDate: String
  }

  connect() {
    this._charts = {}
    this._debounceTimer = null

    this._boundRefresh = () => this.loadData()
    this.element.addEventListener('category-stats:refresh', this._boundRefresh)
  }

  disconnect() {
    this.destroyCharts()
    this.element.removeEventListener('category-stats:refresh', this._boundRefresh)
    if (this._debounceTimer) clearTimeout(this._debounceTimer)
  }

  getSystemColor(type) {
    const style = getComputedStyle(document.documentElement)
    const defaultColor = type === 'income' ? '#22c55e' : '#ef4444'
    return style.getPropertyValue(`--color-${type}`)?.trim() || defaultColor
  }

  onDateChange() {
    this.loadData()
  }

getTimeRange() {
    const type = this.periodTypeTarget?.value || 'month'
    const value = this.periodValueTarget?.value || `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}`

    let start, end

    if (type === 'custom') {
      start = this.startDateTarget?.value || this.startDateValue
      end = this.endDateTarget?.value || this.endDateValue
      if (start && end && new Date(start) > new Date(end)) {
        [start, end] = [end, start]
      }
    } else if (type === 'year') {
      const year = parseInt(value, 10)
      start = `${year}-01-01`
      end = `${year}-12-31`
    } else if (type === 'month') {
      const parts = value.split('-')
      const year = parseInt(parts[0])
      const month = parseInt(parts[1])
      start = `${year}-${String(month).padStart(2, '0')}-01`
      const lastDay = new Date(year, month, 0).getDate()
      end = `${year}-${String(month).padStart(2, '0')}-${lastDay}`
    }

    return { start, end }
  }

  getSelectedCategoryIds() {
    if (!this.hasCategoryCheckboxTarget) return []
    return this.categoryCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
  }

  loadData() {
    if (this._debounceTimer) clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => this._fetchData(), 150)
  }

  async _fetchData() {
    const { start, end } = this.getTimeRange()
    const categoryIds = this.getSelectedCategoryIds()

    let url = `/reports/category_stats?start_date=${start}&end_date=${end}`
    categoryIds.forEach(id => url += `&category_ids[]=${id}`)

    const csrfToken = document.querySelector('[name="csrf-token"]')?.content

    try {
      const res = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        credentials: 'same-origin'
      })
      if (!res.ok) {
        console.error('API error:', res.status)
        return
      }
      const data = await res.json()
      this.updateCharts(data)
    } catch (e) {
      console.error('Fetch error:', e)
    }
  }

  async updateCharts(data) {
    const Chart = await getChartJs()
    if (!Chart) return

    // 收入
    this.updateTotal(this.incomeTotalTarget, data.income.total)
    const hasIncome = data.income.items.length > 0
    this.incomeEmptyTarget.classList.toggle('hidden', hasIncome)
    this.incomeBarChartTarget.classList.toggle('hidden', !hasIncome)
    this.incomeDonutChartTarget.classList.toggle('hidden', !hasIncome)
    if (hasIncome) {
      this._charts.incomeBar = this.updateOrCreateBarChart(Chart, this._charts.incomeBar, this.incomeBarCanvasTarget, 'income', data.income.items)
      this._charts.incomeDonut = this.updateOrCreateDonutChart(Chart, this._charts.incomeDonut, this.incomeDonutCanvasTarget, 'income', data.income.items)
    } else {
      if (this._charts.incomeBar) { this._charts.incomeBar.destroy(); this._charts.incomeBar = null }
      if (this._charts.incomeDonut) { this._charts.incomeDonut.destroy(); this._charts.incomeDonut = null }
    }

    // 支出
    this.updateTotal(this.expenseTotalTarget, data.expense.total)
    const hasExpense = data.expense.items.length > 0
    this.expenseEmptyTarget.classList.toggle('hidden', hasExpense)
    this.expenseBarChartTarget.classList.toggle('hidden', !hasExpense)
    this.expenseDonutChartTarget.classList.toggle('hidden', !hasExpense)
    if (hasExpense) {
      this._charts.expenseBar = this.updateOrCreateBarChart(Chart, this._charts.expenseBar, this.expenseBarCanvasTarget, 'expense', data.expense.items)
      this._charts.expenseDonut = this.updateOrCreateDonutChart(Chart, this._charts.expenseDonut, this.expenseDonutCanvasTarget, 'expense', data.expense.items)
    } else {
      if (this._charts.expenseBar) { this._charts.expenseBar.destroy(); this._charts.expenseBar = null }
      if (this._charts.expenseDonut) { this._charts.expenseDonut.destroy(); this._charts.expenseDonut = null }
    }
  }

  updateOrCreateBarChart(Chart, existingChart, canvas, kind, items) {
    const isDark = document.documentElement.classList.contains('dark')
    const textColor = isDark ? '#f8f9fa' : '#1a1a1a'
    const gridColor = isDark ? '#374151' : '#e9ecef'
    const color = this.getSystemColor(kind)

    if (existingChart) {
      existingChart.data.labels = items.map(i => i.label)
      existingChart.data.datasets[0].data = items.map(i => i.value)
      existingChart.data.datasets[0].backgroundColor = hexToRgba(color, 0.7)
      existingChart.data.datasets[0].borderColor = color
      existingChart.update('default')
      return existingChart
    }

    return new Chart(canvas, {
      type: 'bar',
      data: {
        labels: items.map(i => i.label),
        datasets: [{
          data: items.map(i => i.value),
          backgroundColor: hexToRgba(color, 0.7),
          borderColor: color,
          borderWidth: 1,
          borderRadius: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 400, easing: 'easeOutQuart' },
        plugins: { legend: { display: false } },
        scales: {
          x: { grid: { display: false }, ticks: { color: textColor, font: { size: 10 } } },
          y: { grid: { color: gridColor }, ticks: { color: textColor, font: { size: 10 } } }
        }
      }
    })
  }

  updateOrCreateDonutChart(Chart, existingChart, canvas, kind, items) {
    const isDark = document.documentElement.classList.contains('dark')
    const textColor = isDark ? '#f8f9fa' : '#1a1a1a'
    const baseColor = this.getSystemColor(kind)
    const colors = this.generateColorPalette(baseColor, items.length)

    if (existingChart) {
      existingChart.data.labels = items.map(i => i.label)
      existingChart.data.datasets[0].data = items.map(i => i.value)
      existingChart.data.datasets[0].backgroundColor = colors
      existingChart.update('default')
      return existingChart
    }

    return new Chart(canvas, {
      type: 'doughnut',
      data: {
        labels: items.map(i => i.label),
        datasets: [{
          data: items.map(i => i.value),
          backgroundColor: colors,
          borderWidth: 2,
          borderColor: isDark ? '#1f2937' : '#fff'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '60%',
        animation: { animateRotate: true, animateScale: true, duration: 400, easing: 'easeOutQuart' },
        plugins: {
          legend: {
            position: 'right',
            labels: { color: textColor, usePointStyle: true, padding: 8, font: { size: 10 } }
          }
        }
      }
    })
  }

  generateColorPalette(baseColor, count) {
    const colors = []
    for (let i = 0; i < count; i++) {
      const opacity = 1 - (i * 0.08)
      colors.push(hexToRgba(baseColor, Math.max(0.3, opacity)))
    }
    return colors
  }

  updateTotal(target, value) {
    const fmt = value >= 10000 ? `${(value / 10000).toFixed(2)}万` : value.toFixed(2)
    target.textContent = `¥${fmt}`
  }

  destroyCharts() {
    Object.values(this._charts).forEach(c => c && c.destroy())
    this._charts = {}
  }

  refresh() {
    this.loadData()
  }
}