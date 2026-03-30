import { Controller } from "@hotwired/stimulus"

// Color themes for income/expense colors
const COLOR_THEMES = {
  default: {
    name: "默认 (收入红/支出绿)",
    income: "#ef4444",
    expense: "#22c55e"
  },
  original: {
    name: "原色 (收入绿/支出红)",
    income: "#22c55e",
    expense: "#ef4444"
  },
  blue_orange: {
    name: "蓝/橙",
    income: "#3b82f6",
    expense: "#f97316"
  },
  purple_yellow: {
    name: "紫/黄",
    income: "#8b5cf6",
    expense: "#eab308"
  },
  cyan_pink: {
    name: "青/粉",
    income: "#06b6d4",
    expense: "#ec4899"
  },
  teal_rose: {
    name: "青绿/玫瑰",
    income: "#14b8a6",
    expense: "#f43f5e"
  },
  indigo_amber: {
    name: "靛蓝/琥珀",
    income: "#6366f1",
    expense: "#f59e0b"
  }
}

export default class extends Controller {
  static targets = ["select"]

  initialize() {
    this.boundLoadTheme = this.loadTheme.bind(this)
  }

  connect() {
    this.loadTheme()
    document.addEventListener('turbo:load', this.boundLoadTheme)
  }

  disconnect() {
    document.removeEventListener('turbo:load', this.boundLoadTheme)
  }

  loadTheme() {
    let savedTheme = "reversed"
    try {
      savedTheme = localStorage.getItem("colorTheme") || "reversed"
    } catch (e) {
      console.warn('Failed to read color theme from localStorage:', e)
    }
    this.applyTheme(savedTheme)
    if (this.hasSelectTarget) {
      const select = this.selectTarget
      const optionExists = Array.from(select.options).some(opt => opt.value === savedTheme)
      select.value = optionExists ? savedTheme : "default"
    }
  }

  change(event) {
    const themeName = event.target.value
    this.applyTheme(themeName)
    try {
      localStorage.setItem("colorTheme", themeName)
    } catch (e) {
      console.warn('Failed to save color theme to localStorage:', e)
    }
  }

  applyTheme(themeName) {
    const theme = COLOR_THEMES[themeName] || COLOR_THEMES.default
    
    document.documentElement.style.setProperty("--color-income", theme.income)
    document.documentElement.style.setProperty("--color-expense", theme.expense)
    
    document.documentElement.setAttribute("data-color-theme", themeName)
    
    window.dispatchEvent(new CustomEvent("colorThemeChanged", { detail: { theme: themeName, colors: theme } }))
  }

  static getCurrentColors() {
    let themeName = "reversed"
    try {
      themeName = localStorage.getItem("colorTheme") || "reversed"
    } catch (e) {
      console.warn('Failed to read color theme from localStorage:', e)
    }
    return COLOR_THEMES[themeName] || COLOR_THEMES.default
  }
}

export { COLOR_THEMES }
