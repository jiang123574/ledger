let chartJsPromise = null

export async function getChartJs() {
  if (typeof Chart !== "undefined") {
    return Chart
  }

  if (!chartJsPromise) {
    chartJsPromise = new Promise((resolve, reject) => {
      if (typeof Chart !== "undefined") {
        resolve(Chart)
        return
      }

      const script = document.createElement("script")
      script.src = "https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"
      script.onload = () => resolve(window.Chart)
      script.onerror = () => reject(new Error("Failed to load Chart.js"))
      document.head.appendChild(script)
    })
  }

  return chartJsPromise
}

/**
 * 将 hex 颜色转为 rgba 字符串
 * @param {string} hex - 如 "#ef4444"
 * @param {number} alpha - 0-1 之间的透明度
 * @returns {string} 如 "rgba(239, 68, 68, 0.1)"
 */
export function hexToRgba(hex, alpha) {
  if (!hex || !hex.startsWith('#')) return `rgba(128, 128, 128, ${alpha})`
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}

/**
 * 从 CSS 变量读取颜色，带回退值
 * @param {string} varName - 如 "--color-chart-asset"
 * @param {string} fallback - 回退 hex 值
 * @returns {string} hex 颜色值
 */
export function getCssColor(varName, fallback = '#888888') {
  const val = getComputedStyle(document.documentElement).getPropertyValue(varName).trim()
  return val || fallback
}
