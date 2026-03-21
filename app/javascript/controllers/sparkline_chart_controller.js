import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chart"]
  static values = {
    data: Array
  }

  connect() {
    this.resizeObserver = new ResizeObserver(() => this.draw())
    this.resizeObserver.observe(this.element)
    
    if (this.hasDataValue && this.dataValue && this.dataValue.length > 0) {
      this.draw()
    }
  }

  disconnect() {
    this.resizeObserver?.disconnect()
  }

  dataValueChanged() {
    this.draw()
  }

  draw() {
    const chart = this.chartTarget
    if (!chart) return

    const data = this.dataValue
    if (!data || data.length === 0) {
      chart.innerHTML = '<text x="50%" y="50%" text-anchor="middle" fill="#6c757d" font-size="14">暂无数据</text>'
      return
    }

    const numericData = data.map(v => parseFloat(v) || 0)
    const width = this.element.clientWidth || 300
    const height = this.element.clientHeight || 150
    const padding = { top: 10, right: 10, bottom: 10, left: 10 }
    const chartWidth = width - padding.left - padding.right
    const chartHeight = height - padding.top - padding.bottom

    chart.setAttribute("viewBox", `0 0 ${width} ${height}`)
    chart.innerHTML = ""

    const min = Math.min(...numericData)
    const max = Math.max(...numericData)
    const range = max - min || 1

    const points = numericData.map((value, index) => {
      const x = padding.left + (index / (numericData.length - 1)) * chartWidth
      const y = padding.top + chartHeight - ((value - min) / range) * chartHeight
      return { x, y, value }
    })

    if (points.length === 0) return

    const linePath = points.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x} ${p.y}`).join(" ")

    const gradientId = `gradient-${Math.random().toString(36).substr(2, 9)}`
    const gradient = document.createElementNS("http://www.w3.org/2000/svg", "defs")
    gradient.innerHTML = `
      <linearGradient id="${gradientId}" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#3b82f6" />
        <stop offset="100%" stop-color="#3b82f6" stop-opacity="0" />
      </linearGradient>
    `
    chart.appendChild(gradient)

    const areaPath = linePath + ` L ${points[points.length - 1].x} ${height - padding.bottom} L ${points[0].x} ${height - padding.bottom} Z`
    const area = document.createElementNS("http://www.w3.org/2000/svg", "path")
    area.setAttribute("d", areaPath)
    area.setAttribute("fill", `url(#${gradientId})`)
    area.setAttribute("opacity", "0.2")
    chart.appendChild(area)

    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    path.setAttribute("d", linePath)
    path.setAttribute("fill", "none")
    path.setAttribute("stroke", "#3b82f6")
    path.setAttribute("stroke-width", "2")
    path.setAttribute("stroke-linecap", "round")
    path.setAttribute("stroke-linejoin", "round")
    chart.appendChild(path)

    const lastPoint = points[points.length - 1]
    const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle")
    dot.setAttribute("cx", lastPoint.x)
    dot.setAttribute("cy", lastPoint.y)
    dot.setAttribute("r", "4")
    dot.setAttribute("fill", "#3b82f6")
    dot.setAttribute("stroke", "white")
    dot.setAttribute("stroke-width", "2")
    chart.appendChild(dot)
  }
}
