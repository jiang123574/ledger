import { Controller } from "@hotwired/stimulus"

// 通用迷你折线图控制器
// 支持: 简单数组数据 + 对象数据格式
// 合并: sparkline_chart + time_series_chart

export default class extends Controller {
  static targets = ["chart"]
  static values = {
    data: Array,
    interactive: { type: Boolean, default: false },  // tooltip 交互
    showGrid: { type: Boolean, default: false },     // 网格线
    showEndpoint: { type: Boolean, default: true },  // 末尾点指示器
    height: { type: Number, default: 150 },
    strokeColor: { type: String, default: "#3b82f6" }
  }

  _resizeObserver = null

  connect() {
    // ResizeObserver
    this._resizeObserver = new ResizeObserver(() => this.draw())
    this._resizeObserver.observe(this.element)

    if (this.hasDataValue && this.dataValue?.length > 0) {
      this.draw()
    }
  }

  disconnect() {
    this._resizeObserver?.disconnect()
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

    // 自动检测数据格式
    const isObjectFormat = data.length > 0 && typeof data[0] === 'object' && data[0].hasOwnProperty('value')

    // 提取数值
    const values = isObjectFormat ? data.map(d => d.value) : data.map(v => parseFloat(v) || 0)

    const width = this.element.clientWidth || 300
    const height = this.heightValue
    const padding = { top: 20, right: 20, bottom: 30, left: 50 }
    const chartWidth = width - padding.left - padding.right
    const chartHeight = height - padding.top - padding.bottom

    chart.setAttribute("viewBox", `0 0 ${width} ${height}`)
    chart.innerHTML = ""

    const min = Math.min(...values)
    const max = Math.max(...values)
    const range = max - min || 1

    const xScale = (index) => padding.left + (index / (values.length - 1 || 1)) * chartWidth
    const yScale = (value) => padding.top + chartHeight - ((value - min) / range) * chartHeight

    // 构建点数据
    const linePoints = values.map((value, index) => ({
      x: xScale(index),
      y: yScale(value),
      value,
      date: isObjectFormat ? data[index]?.date : null
    }))

    const linePath = linePoints.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x} ${p.y}`).join(" ")

    // 渐变定义
    const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs")
    defs.innerHTML = `
      <linearGradient id="lineGradient" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="${this.strokeColorValue}" />
        <stop offset="100%" stop-color="${this.strokeColorValue}" stop-opacity="0" />
      </linearGradient>
    `
    chart.appendChild(defs)

    // 网格线（可选）
    if (this.showGridValue) {
      const grid = document.createElementNS("http://www.w3.org/2000/svg", "g")
      grid.setAttribute("class", "grid")
      for (let i = 0; i <= 4; i++) {
        const y = padding.top + (chartHeight / 4) * i
        const line = document.createElementNS("http://www.w3.org/2000/svg", "line")
        line.setAttribute("x1", padding.left)
        line.setAttribute("x2", width - padding.right)
        line.setAttribute("y1", y)
        line.setAttribute("y2", y)
        line.setAttribute("stroke", "#e9ecef")
        line.setAttribute("stroke-dasharray", "4")
        grid.appendChild(line)
      }
      chart.appendChild(grid)
    }

    // 面积填充
    const area = document.createElementNS("http://www.w3.org/2000/svg", "path")
    const areaPath = linePath + ` L ${linePoints[linePoints.length - 1]?.x || 0} ${padding.top + chartHeight} L ${linePoints[0]?.x || 0} ${padding.top + chartHeight} Z`
    area.setAttribute("d", areaPath)
    area.setAttribute("fill", "url(#lineGradient)")
    area.setAttribute("opacity", "0.3")
    chart.appendChild(area)

    // 折线
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    path.setAttribute("d", linePath)
    path.setAttribute("fill", "none")
    path.setAttribute("stroke", this.strokeColorValue)
    path.setAttribute("stroke-width", "2")
    path.setAttribute("stroke-linecap", "round")
    path.setAttribute("stroke-linejoin", "round")
    chart.appendChild(path)

    // 末尾点指示器（可选）
    if (this.showEndpointValue && linePoints.length > 0) {
      const lastPoint = linePoints[linePoints.length - 1]
      const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle")
      dot.setAttribute("cx", lastPoint.x)
      dot.setAttribute("cy", lastPoint.y)
      dot.setAttribute("r", "4")
      dot.setAttribute("fill", this.strokeColorValue)
      dot.setAttribute("stroke", "white")
      dot.setAttribute("stroke-width", "2")
      chart.appendChild(dot)
    }

    // Tooltip 交互（可选）
    if (this.interactiveValue) {
      this.setupTooltipInteraction(chart, linePoints, padding, chartHeight)
    }
  }

  setupTooltipInteraction(chart, linePoints, padding, chartHeight) {
    const tooltipLine = document.createElementNS("http://www.w3.org/2000/svg", "line")
    tooltipLine.setAttribute("class", "tooltip-line")
    tooltipLine.setAttribute("y1", padding.top)
    tooltipLine.setAttribute("y2", padding.top + chartHeight)
    tooltipLine.setAttribute("stroke", this.strokeColorValue)
    tooltipLine.setAttribute("stroke-width", "1")
    tooltipLine.setAttribute("stroke-dasharray", "4")
    tooltipLine.style.opacity = "0"
    chart.appendChild(tooltipLine)

    const tooltipDot = document.createElementNS("http://www.w3.org/2000/svg", "circle")
    tooltipDot.setAttribute("class", "tooltip-dot")
    tooltipDot.setAttribute("r", "5")
    tooltipDot.setAttribute("fill", this.strokeColorValue)
    tooltipDot.setAttribute("stroke", "white")
    tooltipDot.setAttribute("stroke-width", "2")
    tooltipDot.style.opacity = "0"
    chart.appendChild(tooltipDot)

    const tooltipBox = document.createElementNS("http://www.w3.org/2000/svg", "g")
    tooltipBox.style.opacity = "0"
    tooltipBox.innerHTML = `
      <rect x="-30" y="-35" width="60" height="28" rx="4" fill="#1a1a1a" />
      <text x="0" y="-18" text-anchor="middle" fill="white" font-size="12" font-weight="600">¥0.00</text>
    `
    chart.appendChild(tooltipBox)

    chart.addEventListener("mousemove", (e) => {
      const rect = chart.getBoundingClientRect()
      const mouseX = e.clientX - rect.left

      let closestIndex = 0
      let closestDist = Infinity
      linePoints.forEach((p, i) => {
        const dist = Math.abs(p.x - mouseX)
        if (dist < closestDist) {
          closestDist = dist
          closestIndex = i
        }
      })

      const point = linePoints[closestIndex]
      tooltipLine.setAttribute("x1", point.x)
      tooltipLine.setAttribute("x2", point.x)
      tooltipLine.style.opacity = "1"

      tooltipDot.setAttribute("cx", point.x)
      tooltipDot.setAttribute("cy", point.y)
      tooltipDot.style.opacity = "1"

      tooltipBox.setAttribute("transform", `translate(${point.x}, ${point.y})`)
      tooltipBox.style.opacity = "1"
      const textEl = tooltipBox.querySelector("text")
      if (textEl) textEl.textContent = `¥${point.value.toFixed(2)}`
    })

    chart.addEventListener("mouseleave", () => {
      tooltipLine.style.opacity = "0"
      tooltipDot.style.opacity = "0"
      tooltipBox.style.opacity = "0"
    })
  }
}