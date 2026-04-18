import { Controller } from "@hotwired/stimulus"
import { getChartJs, hexToRgba, getCssColor } from "controllers/utils/chartjs_helper"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    labels: Array,
    netWorthData: Array
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

  labelsValueChanged() {
    if (this.labelsValue && this.labelsValue.length > 0) {
      this.drawChart()
    }
  }

  netWorthDataValueChanged() {
    if (this.netWorthDataValue && this.netWorthDataValue.length > 0) {
      this.drawChart()
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
    const netWorthData = this.netWorthDataValue || []

    if (labels.length === 0) return

    const isDark = document.documentElement.classList.contains("dark")
    const textColor = isDark ? "#f8f9fa" : "#1a1a1a"
    const gridColor = isDark ? "#374151" : "#e9ecef"

    const primaryColor = getCssColor("--color-primary", "#3b82f6")
    const incomeColor = getCssColor("--color-income", "#22c55e")
    const expenseColor = getCssColor("--color-expense", "#ef4444")

    const colors = netWorthData.map((val, i) => {
      if (i === 0) return primaryColor
      const prev = netWorthData[i - 1] || 0
      return val >= prev ? incomeColor : expenseColor
    })

    if (this._chart) {
      this._chart.destroy()
    }

    this._chart = new Chart(canvas, {
      type: "line",
      data: {
        labels: labels,
        datasets: [{
          label: "净资产",
          data: netWorthData,
          borderColor: primaryColor,
          backgroundColor: hexToRgba(primaryColor, 0.1),
          borderWidth: 2,
          pointRadius: 4,
          pointHoverRadius: 6,
          pointBackgroundColor: colors,
          pointBorderColor: colors,
          segment: {
            borderColor: (ctx) => {
              const p1 = ctx.p1.parsed.y
              const p0 = ctx.p0.parsed.y
              return p1 >= p0 ? incomeColor : expenseColor
            }
          },
          fill: true,
          tension: 0.3
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: "index",
          intersect: false
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                const val = context.parsed.y
                const idx = context.dataIndex
                const prev = idx > 0 ? netWorthData[idx - 1] : null
                let change = ""
                if (prev !== null) {
                  const diff = val - prev
                  const sign = diff >= 0 ? "+" : ""
                  change = ` (${sign}¥${diff.toFixed(2)})`
                }
                return `净资产: ¥${val.toFixed(2)}${change}`
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: textColor,
              font: { size: 11 }
            }
          },
          y: {
            grid: {
              color: gridColor
            },
            ticks: {
              color: textColor,
              font: { size: 11 },
              callback: (value) => {
                if (Math.abs(value) >= 10000) return (value / 10000).toFixed(1) + "万"
                if (Math.abs(value) >= 1000) return (value / 1000).toFixed(1) + "k"
                return "¥" + value
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