import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    theme: String
  }
  static targets = ["toggle"]

  connect() {
    this.updateThemeClass()
  }

  toggle() {
    const isDark = document.documentElement.classList.contains("dark")
    this.setTheme(!isDark)
  }

  setTheme(isDark) {
    if (isDark) {
      localStorage.theme = "dark"
      document.documentElement.classList.add("dark")
      document.documentElement.setAttribute("data-theme", "dark")
    } else {
      localStorage.theme = "light"
      document.documentElement.classList.remove("dark")
      document.documentElement.setAttribute("data-theme", "light")
    }
    this.updateIcon()
  }

  updateThemeClass() {
    const stored = localStorage.theme
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches

    if (stored === "dark" || (!stored && prefersDark)) {
      document.documentElement.classList.add("dark")
      document.documentElement.setAttribute("data-theme", "dark")
    } else {
      document.documentElement.classList.remove("dark")
      document.documentElement.setAttribute("data-theme", "light")
    }
    this.updateIcon()
  }

  updateIcon() {
    const isDark = document.documentElement.classList.contains("dark")
    const sunIcon = this.element.querySelector("[data-theme-icon='sun']")
    const moonIcon = this.element.querySelector("[data-theme-icon='moon']")

    if (sunIcon) sunIcon.classList.toggle("hidden", !isDark)
    if (moonIcon) moonIcon.classList.toggle("hidden", isDark)
    if (this.hasToggleTarget) this.toggleTarget.checked = isDark
  }
}
