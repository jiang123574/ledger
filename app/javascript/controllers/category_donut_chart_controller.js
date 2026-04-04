import { Controller } from "@hotwired/stimulus"
import { getChartJs } from "controllers/utils/chartjs_helper"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    data: Array,
    type: String,
    selectedCategory: String
  }

  async connect() {
    this.chart = null
    this.selectedIndex = null
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  dataValueChanged() {
    this.drawChart()
  }

  selectedCategoryValueChanged() {
    this.updateSelection()
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
    const values = data.map(d => parseFloat(d.value) || 0)
    const colors = data.map((d, i) => d.color || defaultColors[i % defaultColors.length])
    const categoryIds = data.map(d => d.category_id || d.id || null)

    if (this.chart) {
      this.chart.destroy()
    }

    // 保存 categoryIds 供点击使用
    this.categoryIds = categoryIds

    this.chart = new Chart(canvas, {
      type: "doughnut",
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: colors.map(c => c),
          borderWidth: 2,
          borderColor: isDark ? "#1f2937" : "#ffffff",
          hoverOffset: 8
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "60%",
        onClick: (event, elements) => {
          if (elements.length > 0) {
            const index = elements[0].index
            this.handleSliceClick(index)
          }
        },
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
            },
            onClick: (event, legendItem, legend) => {
              const index = legendItem.index
              this.handleSliceClick(index)
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

  handleSliceClick(index) {
    const categoryId = this.categoryIds[index]
    
    // 切换选中状态
    if (this.selectedIndex === index) {
      // 取消选中
      this.selectedIndex = null
      this.selectedCategoryValue = ""
      this.resetColors()
      this.dispatchFilter(null)
    } else {
      // 选中当前
      this.selectedIndex = index
      this.selectedCategoryValue = categoryId ? String(categoryId) : ""
      this.highlightSlice(index)
      this.dispatchFilter(categoryId)
    }
  }

  highlightSlice(selectedIndex) {
    if (!this.chart) return

    const isDark = document.documentElement.classList.contains("dark")
    const defaultColors = [
      "#ef4444", "#f97316", "#eab308", "#84cc16",
      "#22c55e", "#14b8a6", "#06b6d4", "#0ea5e9",
      "#3b82f6", "#6366f1", "#8b5cf6", "#a855f7"
    ]

    const data = this.dataValue || []
    const originalColors = data.map((d, i) => d.color || defaultColors[i % defaultColors.length])

    // 高亮选中的，其他变淡
    const newColors = originalColors.map((color, i) => {
      if (i === selectedIndex) {
        return color
      } else {
        // 未选中的变淡
        return this.adjustColorOpacity(color, 0.3)
      }
    })

    this.chart.data.datasets[0].backgroundColor = newColors
    this.chart.update()
  }

  resetColors() {
    if (!this.chart) return

    const isDark = document.documentElement.classList.contains("dark")
    const defaultColors = [
      "#ef4444", "#f97316", "#eab308", "#84cc16",
      "#22c55e", "#14b8a6", "#06b6d4", "#0ea5e9",
      "#3b82f6", "#6366f1", "#8b5cf6", "#a855f7"
    ]

    const data = this.dataValue || []
    const originalColors = data.map((d, i) => d.color || defaultColors[i % defaultColors.length])

    this.chart.data.datasets[0].backgroundColor = originalColors
    this.chart.update()
  }

  adjustColorOpacity(color, opacity) {
    // 将颜色转换为 rgba
    const hex = color.replace('#', '')
    const r = parseInt(hex.substring(0, 2), 16)
    const g = parseInt(hex.substring(2, 4), 16)
    const b = parseInt(hex.substring(4, 6), 16)
    return `rgba(${r}, ${g}, ${b}, ${opacity})`
  }

  dispatchFilter(categoryId) {
    // 触发自定义事件，让其他组件可以监听
    this.element.dispatchEvent(new CustomEvent('category-filter', {
      bubbles: true,
      detail: {
        categoryId: categoryId,
        type: this.typeValue
      }
    }))
  }

  updateSelection() {
    // 根据外部设置的 selectedCategoryValue 更新选中状态
    const categoryId = this.selectedCategoryValue
    if (!categoryId || !this.categoryIds) {
      this.selectedIndex = null
      this.resetColors()
      return
    }

    const index = this.categoryIds.findIndex(id => String(id) === categoryId)
    if (index !== -1) {
      this.selectedIndex = index
      this.highlightSlice(index)
    }
  }
}