import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chart"]
  static values = {
    data: Array,
    period: String,
    height: Number
  }

  connect() {
    this.periodValue = this.dataValue?.period || "1M"
    this.heightValue = this.heightValue || 300
    this.draw()
  }

  dataValueChanged() {
    this.draw()
  }

  periodValueChanged() {
    this.draw()
  }

  draw() {
    const chart = this.chartTarget
    if (!chart) return

    const data = this.dataValue
    if (!data || data.length === 0) {
      chart.innerHTML = '<text x="50%" y="50%" text-anchor="middle" fill="#6c757d">暂无数据</text>'
      return
    }

    const width = chart.clientWidth || 600
    const height = this.heightValue
    const padding = { top: 20, right: 20, bottom: 30, left: 50 }
    const innerWidth = width - padding.left - padding.right
    const innerHeight = height - padding.top - padding.bottom

    chart.setAttribute("viewBox", `0 0 ${width} ${height}`)
    chart.innerHTML = ""

    const values = data.map(d => d.value)
    const min = Math.min(...values)
    const max = Math.max(...values)
    const range = max - min || 1

    const xScale = (index) => padding.left + (index / (data.length - 1)) * innerWidth
    const yScale = (value) => padding.top + innerHeight - ((value - min) / range) * innerHeight

    const linePoints = data.map((d, i) => ({ x: xScale(i), y: yScale(d.value), date: d.date, value: d.value }))
    const linePath = linePoints.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x} ${p.y}`).join(" ")

    const grid = document.createElementNS("http://www.w3.org/2000/svg", "g")
    grid.setAttribute("class", "grid")

    for (let i = 0; i <= 4; i++) {
      const y = padding.top + (innerHeight / 4) * i
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

    const area = document.createElementNS("http://www.w3.org/2000/svg", "path")
    const areaPath = linePath + ` L ${linePoints[linePoints.length - 1].x} ${padding.top + innerHeight} L ${linePoints[0].x} ${padding.top + innerHeight} Z`
    area.setAttribute("d", areaPath)
    area.setAttribute("fill", "url(#lineGradient)")
    area.setAttribute("opacity", "0.3")
    chart.appendChild(area)

    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    path.setAttribute("d", linePath)
    path.setAttribute("fill", "none")
    path.setAttribute("stroke", "#3b82f6")
    path.setAttribute("stroke-width", "2")
    path.setAttribute("stroke-linecap", "round")
    path.setAttribute("stroke-linejoin", "round")
    chart.appendChild(path)

    const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs")
    defs.innerHTML = `
      <linearGradient id="lineGradient" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#3b82f6" />
        <stop offset="100%" stop-color="#3b82f6" stop-opacity="0" />
      </linearGradient>
    `
    chart.appendChild(defs)

    const tooltipLine = document.createElementNS("http://www.w3.org/2000/svg", "line")
    tooltipLine.setAttribute("class", "tooltip-line")
    tooltipLine.setAttribute("y1", padding.top)
    tooltipLine.setAttribute("y2", padding.top + innerHeight)
    tooltipLine.setAttribute("stroke", "#3b82f6")
    tooltipLine.setAttribute("stroke-width", "1")
    tooltipLine.setAttribute("stroke-dasharray", "4")
    tooltipLine.style.opacity = "0"
    chart.appendChild(tooltipLine)

    const tooltipDot = document.createElementNS("http://www.w3.org/2000/svg", "circle")
    tooltipDot.setAttribute("class", "tooltip-dot")
    tooltipDot.setAttribute("r", "5")
    tooltipDot.setAttribute("fill", "#3b82f6")
    tooltipDot.setAttribute("stroke", "white")
    tooltipDot.setAttribute("stroke-width", "2")
    tooltipDot.style.opacity = "0"
    chart.appendChild(tooltipDot)

    const tooltipBox = document.createElementNS("http://www.w3.org/2000/svg", "g")
    tooltipBox.style.opacity = "0"
    tooltipBox.innerHTML = `
      <rect x="-30" y="-35" width="60" height="28" rx="4" fill="#1a1a1a" />
      <text x="0" y="-18" text-anchor="middle" fill="white" font-size="12" font-weight="600">¥${data[data.length - 1]?.value.toFixed(2) || 0}</text>
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
