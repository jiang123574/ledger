import { Controller } from "@hotwired/stimulus"
import { getChartJs } from "controllers/utils/chartjs_helper"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    labels: Array,
    incomeData: Array,
    expenseData: Array
  }

  async connect() {
    this.chart = null
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  labelsValueChanged() {
    this.drawChart()
  }

  incomeDataValueChanged() {
    this.drawChart()
  }

  expenseDataValueChanged() {
    this.drawChart()
  }

  async drawChart() {
    const canvas = this.canvasTarget
    if (!canvas) return

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

    if (this.chart) {
      this.chart.destroy()
    }

    this.chart = new Chart(canvas, {
      type: "line",
      data: {
        labels: labels,
        datasets: [
          {
            label: "收入",
            data: incomeData,
            borderColor: incomeColor,
            backgroundColor: this.hexToRgba(incomeColor, 0.1),
            fill: true,
            tension: 0.3,
            pointRadius: 3,
            pointHoverRadius: 6
          },
          {
            label: "支出",
            data: expenseData,
            borderColor: expenseColor,
            backgroundColor: this.hexToRgba(expenseColor, 0.1),
            fill: true,
            tension: 0.3,
            pointRadius: 3,
            pointHoverRadius: 6
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
              padding: 20
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
              color: gridColor,
              display: false
            },
            ticks: {
              color: textColor
            }
          },
          y: {
            grid: {
              color: gridColor
            },
            ticks: {
              color: textColor,
              callback: (value) => `¥${value}`
            }
          }
        }
      }
    })
  }

  hexToRgba(hex, alpha) {
    const r = parseInt(hex.slice(1, 3), 16)
    const g = parseInt(hex.slice(3, 5), 16)
    const b = parseInt(hex.slice(5, 7), 16)
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }
}
