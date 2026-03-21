import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    data: Array,
    size: Number,
    innerRadius: Number,
    colors: Array
  }

  connect() {
    this.draw()
  }

  dataValueChanged() {
    this.draw()
  }

  draw() {
    const chart = this.chartTarget
    const legend = this.legendTarget
    if (!chart) return

    const data = this.dataValue
    if (!data || data.length === 0) {
      chart.innerHTML = '<p class="text-center text-gray-500 py-8">暂无数据</p>'
      return
    }

    const size = this.sizeValue || 200
    const innerRadius = this.innerRadiusValue || size * 0.5
    const outerRadius = size / 2
    const colors = this.colorsValue || ['#ef4444', '#f97316', '#eab308', '#84cc16', '#22c55e', '#14b8a6', '#06b6d4', '#0ea5e9', '#3b82f6', '#6366f1']

    chart.innerHTML = ""
    chart.setAttribute("width", size)
    chart.setAttribute("height", size)
    chart.setAttribute("viewBox", `0 0 ${size} ${size}`)

    const total = data.reduce((sum, d) => sum + d.value, 0)
    
    // Create SVG group centered
    const cx = size / 2
    const cy = size / 2
    
    // Draw arcs
    let currentAngle = -Math.PI / 2 // Start from top
    
    data.forEach((item, index) => {
      const sliceAngle = (item.value / total) * Math.PI * 2
      const endAngle = currentAngle + sliceAngle
      
      // Calculate arc path
      const x1 = cx + outerRadius * Math.cos(currentAngle)
      const y1 = cy + outerRadius * Math.sin(currentAngle)
      const x2 = cx + outerRadius * Math.cos(endAngle)
      const y2 = cy + outerRadius * Math.sin(endAngle)
      
      const ix1 = cx + innerRadius * Math.cos(currentAngle)
      const iy1 = cy + innerRadius * Math.sin(currentAngle)
      const ix2 = cx + innerRadius * Math.cos(endAngle)
      const iy2 = cy + innerRadius * Math.sin(endAngle)
      
      const largeArc = sliceAngle > Math.PI ? 1 : 0
      
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
      path.setAttribute("d", `
        M ${x1} ${y1}
        A ${outerRadius} ${outerRadius} 0 ${largeArc} 1 ${x2} ${y2}
        L ${ix2} ${iy2}
        A ${innerRadius} ${innerRadius} 0 ${largeArc} 0 ${ix1} ${iy1}
        Z
      `)
      path.setAttribute("fill", item.color || colors[index % colors.length])
      path.setAttribute("stroke", "white")
      path.setAttribute("stroke-width", "2")
      path.style.cursor = "pointer"
      path.style.transition = "opacity 0.2s"
      
      path.addEventListener("mouseenter", () => {
        path.style.opacity = "0.8"
        this.updateLegend(item, total)
      })
      path.addEventListener("mouseleave", () => {
        path.style.opacity = "1"
        this.clearLegend(total)
      })
      
      chart.appendChild(path)
      currentAngle = endAngle
    })

    this.clearLegend(total)
  }

  updateLegend(item, total) {
    const legend = this.legendTarget
    if (!legend) return

    const percentage = ((item.value / total) * 100).toFixed(1)
    legend.innerHTML = `
      <div class="text-center">
        <p class="text-2xl font-bold" style="color: ${item.color}">${percentage}%</p>
        <p class="text-sm text-gray-500 dark:text-gray-400 truncate max-w-[100px]">${item.label}</p>
      </div>
    `
  }

  clearLegend(total) {
    const legend = this.legendTarget
    if (!legend) return

    legend.innerHTML = `
      <div class="text-center">
        <p class="text-2xl font-bold text-gray-900 dark:text-white">¥${total.toFixed(2)}</p>
        <p class="text-sm text-gray-500 dark:text-gray-400">总计</p>
      </div>
    `
  }
}
