import { Controller } from "@hotwired/stimulus"
import { getChartJs, hexToRgba } from "controllers/utils/chartjs_helper"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    labels: Array,
    incomeData: Array,
    expenseData: Array
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

  incomeDataValueChanged() {
    if (this.incomeDataValue && this.incomeDataValue.length > 0) {
      this.drawChart()
    }
  }

  expenseDataValueChanged() {
    if (this.expenseDataValue && this.expenseDataValue.length > 0) {
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
    const incomeData = this.incomeDataValue || []
    const expenseData = this.expenseDataValue || []

    if (labels.length === 0) return

    const isDark = document.documentElement.classList.contains("dark")
    const textColor = isDark ? "#f8f9fa" : "#1a1a1a"
    const gridColor = isDark ? "#374151" : "#e9ecef"
    const incomeColor = getComputedStyle(document.documentElement).getPropertyValue("--color-income").trim() || "#22c55e"
    const expenseColor = getComputedStyle(document.documentElement).getPropertyValue("--color-expense").trim() || "#ef4444"

    if (this._chart) {
      this._chart.destroy()
    }

    this._chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: labels,
        datasets: [
          {
            label: "收入",
            data: incomeData,
            backgroundColor: hexToRgba(incomeColor, 0.7),
            borderColor: incomeColor,
            borderWidth: 1,
            borderRadius: 4,
            barPercentage: 0.6
          },
          {
            label: "支出",
            data: expenseData,
            backgroundColor: hexToRgba(expenseColor, 0.7),
            borderColor: expenseColor,
            borderWidth: 1,
            borderRadius: 4,
            barPercentage: 0.6
          }
        ]
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
            position: "top",
            labels: {
              color: textColor,
              usePointStyle: true,
              padding: 16
            }
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                return `${context.dataset.label}: ¥${context.raw?.toFixed(2) || 0}`
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
