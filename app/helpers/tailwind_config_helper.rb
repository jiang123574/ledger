# TailwindConfigHelper - 为 Tailwind v4 CDN 提供配置
module TailwindConfigHelper
  def self.theme_extensions
    {
      fontFamily: {
        sans: [ "Geist", "system-ui", "-apple-system", "BlinkMacSystemFont", "Segoe UI", "sans-serif" ],
        mono: [ "Geist Mono", "ui-monospace", "SFMono-Regular", "Menlo", "Monaco", "Consolas", "monospace" ]
      },
      colors: {
        surface: {
          DEFAULT: "#f8f9fa",
          hover: "#f1f3f5",
          inset: "#e9ecef",
          dark: "#1a1a1a",
          'dark-hover': "#262626",
          'dark-inset': "#262626"
        },
        container: {
          DEFAULT: "#ffffff",
          inset: "#f8f9fa",
          dark: "#262626",
          'dark-inset': "#1a1a1a"
        },
        primary: {
          DEFAULT: "#1a1a1a",
          hover: "#333333",
          dark: "#f8f9fa",
          'dark-hover': "#e9ecef"
        },
        secondary: {
          DEFAULT: "#6c757d",
          hover: "#495057",
          dark: "#9ca3af",
          'dark-hover': "#d1d5db"
        },
        border: {
          DEFAULT: "#dee2e6",
          secondary: "#e9ecef",
          dark: "#404040",
          'dark-secondary': "#333333"
        },
        inverse: {
          DEFAULT: "#1a1a1a",
          hover: "#333333",
          dark: "#f8f9fa",
          'dark-hover': "#e9ecef"
        },
        income: {
          DEFAULT: "var(--color-income, #ef4444)",
          soft: "rgba(var(--color-income-rgb, 239, 68, 68), 0.1)",
          light: "rgba(var(--color-income-rgb, 239, 68, 68), 0.2)"
        },
        expense: {
          DEFAULT: "var(--color-expense, #22c55e)",
          soft: "rgba(var(--color-expense-rgb, 34, 197, 94), 0.1)",
          light: "rgba(var(--color-expense-rgb, 34, 197, 94), 0.2)"
        },
        transfer: "#3b82f6"
      }
    }
  end
end
