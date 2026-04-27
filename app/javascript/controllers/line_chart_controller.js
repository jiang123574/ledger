import { Controller } from "@hotwired/stimulus"
import { getChartJs, hexToRgba, getCssColor } from "controllers/utils/chartjs_helper"

// 通用折线图控制器
// 支持: 单线/多线、涨跌配色(segment colors)、tooltip变化值
// 用于合并: trend_line_chart + net_worth_trend

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    labels: Array,
    datasets: Array,           // [{label, data, colorVar, fill, borderDash, borderWidth}]
    segmentColors: { type: Boolean, default: false },  // 涨跌配色
    showLegend: { type: Boolean, default: true },
    showChangeInTooltip: { type: Boolean, default: false },
    tension: { type: Number, default: 0.3 },
    pointRadius: { type: Number, default: 3 }
  }

  _resizeObserver = null
  _chart = null
  _pendingRender = false

  async connect() {
    // ResizeObserver 监听
    this._resizeObserver = new ResizeObserver(() => {
      if (this._chart && this.element.offsetParent !== null) {
        this._chart.resize()
      }
    })
    this._resizeObserver.observe(this.element)

    // 延迟渲染处理（hidden 元素）
    if (this.element.offsetParent === null) {
      this._pendingRender = true
    } else if (this.hasLabelsValue && this.labelsValue?.length > 0) {
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
    if (this.labelsValue?.length > 0) {
      this.drawChart()
    }
  }

  datasetsValueChanged() {
    if (this.datasetsValue?.length > 0) {
      this.drawChart()
    }
  }

  refresh() {
    if (this._pendingRender) {
      this._pendingRender = false
      this.drawChart()
    } else if (this._chart) {
      this._chart.resize()
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
    const datasetsConfig = this.datasetsValue || []

    if (labels.length === 0 || datasetsConfig.length === 0) return

    const isDark = document.documentElement.classList.contains("dark")
    const textColor = isDark ? "#f8f9fa" : "#1a1a1a"
    const gridColor = isDark ? "#374151" : "#e9ecef"

    const incomeColor = getCssColor("--color-income", "#22c55e")
    const expenseColor = getCssColor("--color-expense", "#ef4444")

    // 构建 datasets
    const chartDatasets = datasetsConfig.map((ds, index) => {
      const color = getCssColor(ds.colorVar || "--color-primary", "#3b82f6")
      const data = ds.data || []

      // segment colors（涨跌配色）- 仅用于第一个数据集
      let segment = null
      let pointColors = null

      if (this.segmentColorsValue && index === 0) {
        pointColors = data.map((val, i) => {
          if (i === 0) return color
          const prev = data[i - 1] || 0
          return val >= prev ? incomeColor : expenseColor
        })

        segment = {
          borderColor: (ctx) => {
            const p1 = ctx.p1?.parsed?.y
            const p0 = ctx.p0?.parsed?.y
            if (p1 === undefined || p0 === undefined) return color
            return p1 >= p0 ? incomeColor : expenseColor
          }
        }
      }

      return {
        label: ds.label || `数据集 ${index + 1}`,
        data: data,
        borderColor: color,
        backgroundColor: hexToRgba(color, 0.1),
        borderWidth: ds.borderWidth || 2,
        borderDash: ds.borderDash || [],
        fill: ds.fill !== false,
        tension: this.tensionValue,
        pointRadius: this.pointRadiusValue,
        pointHoverRadius: this.pointRadiusValue + 2,
        pointBackgroundColor: pointColors || color,
        pointBorderColor: pointColors || color,
        segment: segment
      }
    })

    if (this._chart) {
      this._chart.destroy()
    }

    // 获取数据用于 tooltip callback
    const firstDatasetData = chartDatasets[0]?.data || []

    this._chart = new Chart(canvas, {
      type: "line",
      data: {
        labels: labels,
        datasets: chartDatasets
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
            display: this.showLegendValue,
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
                const val = context.parsed.y
                const idx = context.dataIndex

                // tooltip 显示变化值（仅第一个数据集）
                if (this.showChangeInTooltipValue && context.datasetIndex === 0 && idx > 0) {
                  const prev = firstDatasetData[idx - 1]
                  const diff = val - prev
                  const sign = diff >= 0 ? "+" : ""
                  return `${context.dataset.label}: ¥${val.toFixed(2)} (${sign}¥${diff.toFixed(2)})`
                }

                return `${context.dataset.label}: ¥${val.toFixed(2)}`
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
}