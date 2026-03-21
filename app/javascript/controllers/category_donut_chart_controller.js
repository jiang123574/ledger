import { Controller } from "@hotwired/stimulus"
import { getChartJs } from "controllers/utils/chartjs_helper"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    data: Array,
    type: String
  }

  async connect() {
    this.chart = null
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  dataValueChanged() {
    this.drawChart()
  }

  async drawChart() {
    const canvas = this.canvasTarget
    if (!canvas) return

    const Chart = await getChartJs()
    if (!Chart) return

    const data = this.dataValue || []
    if (data.length === 0) return

    const isDark = document.documentElement.classList.contains("dark")
    const textColor = isDark ? "#f8f9fa" : "#1a1a1a"

    const defaultColors = [
      "#ef4444", "#f97316", "#eab308", "#84cc16",
      "#22c55e", "#14b8a6", "#06b6d4", "#0ea5e9",
      "#3b82f6", "#6366f1", "#8b5cf6", "#a855f7"
    ]

    const labels = data.map(d => d.label || "未分类")
    const values = data.map(d => d.value || 0)
    const colors = data.map((d, i) => d.color || defaultColors[i % defaultColors.length])

    if (this.chart) {
      this.chart.destroy()
    }

    this.chart = new Chart(canvas, {
      type: "doughnut",
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: colors,
          borderWidth: 2,
          borderColor: isDark ? "#1f2937" : "#ffffff",
          hoverOffset: 8
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "60%",
        plugins: {
          legend: {
            position: "right",
            labels: {
              color: textColor,
              usePointStyle: true,
              padding: 12,
              font: {
                size: 12
              },
              generateLabels: (chart) => {
                const datasets = chart.data.datasets
                return chart.data.labels.map((label, i) => {
                  const value = datasets[0].data[i]
                  const total = datasets[0].data.reduce((a, b) => a + b, 0)
                  const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0
                  return {
                    text: `${label} (${percentage}%)`,
                    fillStyle: datasets[0].backgroundColor[i],
                    hidden: false,
                    index: i
                  }
                })
              }
            }
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                const value = context.raw || 0
                const total = context.dataset.data.reduce((a, b) => a + b, 0)
                const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0
                return `${context.label}: ¥${value.toFixed(2)} (${percentage}%)`
              }
            }
          }
        }
      }
    })
  }
}
