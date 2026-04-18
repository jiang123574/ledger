import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chart"]
  static values = {
    data: Array,
    year: Number
  }

  connect() {
    if (document.documentElement.hasAttribute('data-turbo-preview')) {
      return
    }
    this.scheduleDraw()
  }

  dataValueChanged() {
    if (document.documentElement.hasAttribute('data-turbo-preview')) {
      return
    }
    this.scheduleDraw()
  }

  scheduleDraw() {
    if (this._drawScheduled) return
    this._drawScheduled = true
    requestAnimationFrame(() => {
      this._drawScheduled = false
      this.draw()
    })
  }

  draw() {
    if (this._drawing) return
    this._drawing = true

    const chart = this.chartTarget
    const data = this.dataValue
    const year = this.yearValue || new Date().getFullYear()

    if (!chart || !data || !Array.isArray(data) || data.length === 0) {
      this._drawing = false
      return
    }

    chart.innerHTML = ""

    const cellSize = 12
    const padding = { top: 30, right: 10, bottom: 10, left: 40 }
    const monthLabelHeight = 20

    const months = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]
    const days = ["日", "一", "二", "三", "四", "五", "六"]

    const width = cellSize * 53 + padding.left + padding.right
    const height = cellSize * 7 + padding.top + padding.bottom + monthLabelHeight

    chart.setAttribute("viewBox", `0 0 ${width} ${height}`)
    chart.style.width = "100%"

    const isDark = document.documentElement.classList.contains("dark")
    const textColor = isDark ? "#f8f9fa" : "#1a1a1a"
    const emptyColor = isDark ? "#262626" : "#f0f0f0"

    const colors = {
      1: isDark ? "#1a3d1a" : "#c6e48b",
      2: isDark ? "#2a5c2a" : "#7bc96f",
      3: isDark ? "#3a7a3a" : "#239a3b",
      4: isDark ? "#4a994a" : "#196127",
      5: isDark ? "#5ab85a" : "#0d4420"
    }

    for (let i = 0; i < months.length; i++) {
      const text = document.createElementNS("http://www.w3.org/2000/svg", "text")
      text.setAttribute("x", padding.left + i * 4.5 * cellSize + cellSize)
      text.setAttribute("y", padding.top - 10)
      text.setAttribute("fill", textColor)
      text.setAttribute("font-size", "11")
      text.setAttribute("text-anchor", "start")
      text.textContent = months[i]
      chart.appendChild(text)
    }

    for (let i = 0; i < days.length; i++) {
      if (i % 2 === 1) continue
      const text = document.createElementNS("http://www.w3.org/2000/svg", "text")
      text.setAttribute("x", padding.left - 5)
      text.setAttribute("y", padding.top + monthLabelHeight + i * cellSize + cellSize / 2 + 4)
      text.setAttribute("fill", textColor)
      text.setAttribute("font-size", "10")
      text.setAttribute("text-anchor", "end")
      text.textContent = days[i]
      chart.appendChild(text)
    }

    const validData = data.filter(d => d && d.date)
    const dataMap = new Map(validData.map(d => [d.date, d]))

    const startDate = new Date(year, 0, 1)
    const endDate = new Date(year, 11, 31)

    let currentDate = new Date(startDate)
    while (currentDate <= endDate) {
      const dayOfWeek = currentDate.getDay()
      const weekOfYear = this.getWeekOfYear(currentDate)

      const dateStr = this.formatDate(currentDate)
      const dayData = dataMap.get(dateStr)

      const x = padding.left + weekOfYear * cellSize
      const y = padding.top + monthLabelHeight + dayOfWeek * cellSize

      const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect")
      rect.setAttribute("x", x)
      rect.setAttribute("y", y)
      rect.setAttribute("width", cellSize - 2)
      rect.setAttribute("height", cellSize - 2)
      rect.setAttribute("rx", 2)
      rect.setAttribute("ry", 2)

      if (dayData && dayData.level) {
        const levelColor = colors[dayData.level] || colors[1]
        rect.setAttribute("fill", levelColor)
        rect.setAttribute("data-date", dateStr)
        rect.setAttribute("data-amount", dayData.amount || 0)
        rect.setAttribute("data-count", dayData.count || 0)
        rect.classList.add("cursor-pointer")

        rect.addEventListener("mouseenter", (e) => {
          this.showTooltip(e, dayData)
        })
        rect.addEventListener("mouseleave", () => {
          this.hideTooltip()
        })
      } else {
        rect.setAttribute("fill", emptyColor)
      }

      chart.appendChild(rect)

      currentDate.setDate(currentDate.getDate() + 1)
    }

    this._drawing = false
  }

  getWeekOfYear(date) {
    const jan1 = new Date(date.getFullYear(), 0, 1)
    const jan1DayOfWeek = jan1.getDay()
    const dayOfYear = Math.floor((date - jan1) / (24 * 60 * 60 * 1000))
    return Math.floor((dayOfYear + jan1DayOfWeek) / 7)
  }

  formatDate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")
    return `${year}-${month}-${day}`
  }

  showTooltip(event, data) {
    let tooltip = document.getElementById("heatmap-tooltip")
    if (!tooltip) {
      tooltip = document.createElement("div")
      tooltip.id = "heatmap-tooltip"
      tooltip.className = "fixed bg-container dark:bg-container-dark text-primary dark:text-primary-dark text-xs px-2 py-1 rounded shadow-lg z-50 pointer-events-none"
      document.body.appendChild(tooltip)
    }

    tooltip.textContent = `${data.date}: ¥${data.amount.toFixed(2)} (${data.count}笔)`
    tooltip.style.left = `${event.clientX + 10}px`
    tooltip.style.top = `${event.clientY - 30}px`
    tooltip.classList.remove("hidden")
  }

  hideTooltip() {
    const tooltip = document.getElementById("heatmap-tooltip")
    if (tooltip) {
      tooltip.classList.add("hidden")
    }
  }
}