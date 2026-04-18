import { Controller } from "@hotwired/stimulus"
import { getChartJs, hexToRgba, getCssColor } from "controllers/utils/chartjs_helper"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    labels: Array,
    data: Array,
    totals: Array
  }

  async connect() {
    this._resizeObserver = new ResizeObserver(() => {
      if (this._chart && this.element.offsetParent !== null) {
        this._chart.resize()
      }
    })
    this._resizeObserver.observe(this.element)
    if (this.hasLabelsValue && this.labelsValue && this.labelsValue.length > 0) {
      await this.drawChart()
    }
  }

  disconnect() {
    if (this._resizeObserver) {
      this._resizeObserver.disconnect()
    }
    if (this._chart) {
      this._chart.destroy()
    }
  }

  async drawChart() {
    const canvas = this.canvasTarget
    if (!canvas) return

    if (this.element.offsetParent === null) {
      this._pendingRender = true
      return
    }

    const Chart = await getChartJs()
    if (!Chart) return

    const labels = this.labelsValue || []
    const data = this.dataValue || []
    const totals = this.totalsValue || []

    if (labels.length === 0) return

    const isDark = document.documentElement.classList.contains("dark")
    const textColor = isDark ? "#f8f9fa" : "#1a1a1a"
    const gridColor = isDark ? "#374151" : "#e9ecef"

    const incomeColor = getCssColor("--color-income", "#22c55e")
    const expenseColor = getCssColor("--color-expense", "#ef4444")
    const neutralColor = isDark ? "#6b7280" : "#9ca3af"

    const colors = data.map((val, i) => {
      if (i === 0) return neutralColor
      if (i === data.length - 1) return neutralColor
      return val >= 0 ? incomeColor : expenseColor
    })

    const baseColors = colors.map(c => hexToRgba(c, 0.7))

    if (this._chart) {
      this._chart.destroy()
    }

    this._chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: labels,
        datasets: [{
          label: "变动",
          data: totals,
          backgroundColor: baseColors,
          borderColor: colors,
          borderWidth: 1,
          borderRadius: 4,
          barPercentage: 0.6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                const idx = context.dataIndex
                const val = data[idx]
                const total = totals[idx]
                if (idx === 0) {
                  return `期初余额: ¥${total.toFixed(2)}`
                }
                if (idx === data.length - 1) {
                  return `期末余额: ¥${total.toFixed(2)}`
                }
                const sign = val >= 0 ? "+" : ""
                return `${sign}¥${val.toFixed(2)} → 余额 ¥${total.toFixed(2)}`
              }
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: textColor, font: { size: 11 } }
          },
          y: {
            grid: { color: gridColor },
            ticks: {
              color: textColor,
              font: { size: 11 },
              callback: (val) => {
                if (Math.abs(val) >= 10000) return (val / 10000).toFixed(1) + "万"
                if (Math.abs(val) >= 1000) return (val / 1000).toFixed(1) + "k"
                return "¥" + val
              }
            }
          }
        }
      }
    })
  }

  refresh() {
    if (this._pendingRender) {
      this._pendingRender = false
      this.drawChart()
    } else if (this._chart) {
      this._chart.resize()
    }
  }
}