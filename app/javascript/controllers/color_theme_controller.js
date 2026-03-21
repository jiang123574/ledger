import { Controller } from "@hotwired/stimulus"

// Color themes for income/expense colors
const COLOR_THEMES = {
  default: {
    name: "默认 (收入绿/支出红)",
    income: "#22c55e",
    expense: "#ef4444"
  },
  reversed: {
    name: "反色 (收入红/支出绿)",
    income: "#ef4444",
    expense: "#22c55e"
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

  connect() {
    // Ensure we read from localStorage and update select value
    this.loadTheme()
    // Also listen for turbo:load in case of page navigation
    document.addEventListener('turbo:load', () => this.loadTheme())
  }

  disconnect() {
    document.removeEventListener('turbo:load', () => this.loadTheme())
  }

  loadTheme() {
    const savedTheme = localStorage.getItem("colorTheme") || "default"
    this.applyTheme(savedTheme)
    if (this.hasSelectTarget) {
      // Set select value, ensuring it matches one of the options
      const select = this.selectTarget
      const optionExists = Array.from(select.options).some(opt => opt.value === savedTheme)
      select.value = optionExists ? savedTheme : "default"
    }
  }

  change(event) {
    const themeName = event.target.value
    this.applyTheme(themeName)
    localStorage.setItem("colorTheme", themeName)
  }

  applyTheme(themeName) {
    const theme = COLOR_THEMES[themeName] || COLOR_THEMES.default
    
    document.documentElement.style.setProperty("--color-income", theme.income)
    document.documentElement.style.setProperty("--color-expense", theme.expense)
    
    // Also update data attributes for CSS selectors
    document.documentElement.setAttribute("data-color-theme", themeName)
    
    // Dispatch event for other components to react
    window.dispatchEvent(new CustomEvent("colorThemeChanged", { detail: { theme: themeName, colors: theme } }))
  }

  // Get current theme colors (utility method)
  static getCurrentColors() {
    const themeName = localStorage.getItem("colorTheme") || "default"
    return COLOR_THEMES[themeName] || COLOR_THEMES.default
  }
}

// Export themes for use in other modules
export { COLOR_THEMES }