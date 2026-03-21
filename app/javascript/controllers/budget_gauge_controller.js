import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    percentage: Number,
    spent: Number,
    total: Number
  }

  connect() {
    this.draw()
  }

  percentageValueChanged() {
    this.draw()
  }

  draw() {
    const percentage = this.percentageValue || 0
    const spent = this.spentValue || 0
    const total = this.totalValue || 0

    const gauge = this.element.querySelector("[data-budget-gauge-target='gauge']")
    const percentageEl = this.element.querySelector("[data-budget-gauge-target='percentage']")
    const spentEl = this.element.querySelector("[data-budget-gauge-target='spent']")
    const totalEl = this.element.querySelector("[data-budget-gauge-target='total']")

    if (!gauge) return

    const size = 120
    const strokeWidth = 12
    const radius = (size - strokeWidth) / 2
    const circumference = radius * 2 * Math.PI
    const offset = circumference - (Math.min(percentage, 100) / 100) * circumference

    const isDark = document.documentElement.classList.contains("dark")
    const bgColor = isDark ? "#374151" : "#e9ecef"
    let progressColor = getComputedStyle(document.documentElement)
      .getPropertyValue("--color-income").trim() || "#22c55e"

    if (percentage > 100) {
      progressColor = "#ef4444"
    } else if (percentage > 80) {
      progressColor = "#f97316"
    }

    gauge.innerHTML = `
      <circle
        class="transform -rotate-90 origin-center"
        cx="${size / 2}"
        cy="${size / 2}"
        r="${radius}"
        fill="none"
        stroke="${bgColor}"
        stroke-width="${strokeWidth}"
      />
      <circle
        class="transform -rotate-90 origin-center transition-all duration-500 ease-out"
        cx="${size / 2}"
        cy="${size / 2}"
        r="${radius}"
        fill="none"
        stroke="${progressColor}"
        stroke-width="${strokeWidth}"
        stroke-linecap="round"
        stroke-dasharray="${circumference}"
        stroke-dashoffset="${offset}"
      />
    `

    if (percentageEl) {
      percentageEl.textContent = `${Math.min(percentage, 999)}%`
      percentageEl.style.color = progressColor
    }

    if (spentEl) {
      spentEl.textContent = `¥${spent.toFixed(2)}`
    }

    if (totalEl) {
      totalEl.textContent = `/ ¥${total.toFixed(2)}`
    }
  }
}
