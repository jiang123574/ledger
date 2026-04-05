import { Controller } from "@hotwired/stimulus"
import { getChartJs } from "controllers/utils/chartjs_helper"

// 资产走势多线折线图（资产/负债/净资产 三线同图）
export default class extends Controller {
  static targets = ["canvas"]

  static values = {
    labels: Array,
    assets: Array,
    liabilities: Array,
    netWorth: Array
  }

  _resizeObserver = null

  async connect() {
    // 监听父元素可见性变化（面板从 hidden 切为 visible）
    this._resizeObserver = new ResizeObserver(() => {
      if (this._chart && this.element.offsetParent !== null) {
        this._chart.resize()
      }
    })
    this._resizeObserver.observe(this.element)

    // 等待元素可见后再渲染
    await this.renderChart()
  }

  async renderChart() {
    const canvas = this.canvasTarget
    if (!canvas) return

    // 如果元素被 hidden，延迟渲染
    if (this.element.offsetParent === null) {
      this._pendingRender = true
      return
    }

    const Chart = await getChartJs()
    if (!Chart) return

    // 销毁旧实例
    if (this._chart) {
      this._chart.destroy()
      this._chart = null
    }

    const ctx = canvas.getContext('2d')
    const labels = this.labelsValue
    const assetsData = this.assetsValue
    const liabilitiesData = this.liabilitiesValue
    const netWorthData = this.netWorthValue

    if (!labels || labels.length === 0) return

    const isDark = document.documentElement.classList.contains("dark")
    const textColor = isDark ? "#f8f9fa" : "#1a1a1a"
    const gridColor = isDark ? "#374151" : "#e9ecef"

    // 确定Y轴范围（让0线居中或合理分布）
    const allValues = [...assetsData, ...liabilitiesData.map(v => -v), ...netWorthData]
    const minVal = Math.min(...allValues, 0)
    const maxVal = Math.max(...allValues, 0)

    this._chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: '资产',
            data: assetsData,
            borderColor: '#ef4444',
            backgroundColor: 'rgba(239, 68, 68, 0.1)',
            borderWidth: 2,
            pointRadius: 3,
            pointHoverRadius: 5,
            pointBackgroundColor: '#ef4444',
            fill: false,
            tension: 0.2
          },
          {
            label: '负债',
            data: liabilitiesData, // 后端已返回负数
            borderColor: '#f59e0b',
            backgroundColor: 'rgba(245, 158, 11, 0.1)',
            borderWidth: 2,
            pointRadius: 3,
            pointHoverRadius: 5,
            pointBackgroundColor: '#f59e0b',
            fill: false,
            tension: 0.2
          },
          {
            label: '净资产',
            data: netWorthData,
            borderColor: '#3b82f6',
            backgroundColor: 'rgba(59, 130, 246, 0.05)',
            borderWidth: 2.5,
            pointRadius: 4,
            pointHoverRadius: 6,
            pointBackgroundColor: '#3b82f6',
            borderDash: [5, 3],
            fill: true,
            tension: 0.2
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false
        },
        plugins: {
          legend: {
            position: 'top',
            labels: { color: textColor, usePointStyle: true, padding: 16 }
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                const val = context.parsed.y
                const formatted = Math.abs(val).toLocaleString('zh-CN', { minimumFractionDigits: 2 })
                const sign = val < 0 ? '-' : ''
                return `${context.datasetLabel}: ${sign}¥${formatted}`
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
                const abs = Math.abs(val)
                if (abs >= 10000) return (val / 10000).toFixed(1) + '万'
                if (abs >= 1000) return (val / 1000).toFixed(1) + 'k'
                return '¥' + val
              }
            }
          }
        }
      }
    })
  }

  // 供 report-tabs 面板切换后调用
  refresh() {
    if (this._pendingRender) {
      this._pendingRender = false
      this.renderChart()
    } else if (this._chart) {
      this._chart.resize()
    }
  }

  disconnect() {
    if (this._resizeObserver) {
      this._resizeObserver.disconnect()
      this._resizeObserver = null
    }
    if (this._chart) {
      this._chart.destroy()
      this._chart = null
    }
  }
}
