let chartJsPromise = null
let chartJsLoaded = false

/**
 * 动态加载 Chart.js（仅在需要图表的页面加载）
 * 使用 import() 动态导入，实现按需加载
 * @returns {Promise<Chart|null>}
 */
export async function getChartJs() {
  if (typeof Chart !== "undefined") {
    return Chart
  }

  if (!chartJsPromise) {
    chartJsPromise = new Promise((resolve, reject) => {
      // 检查是否已加载（UMD 方式可能已注入全局 Chart）
      if (typeof Chart !== "undefined") {
        chartJsLoaded = true
        resolve(Chart)
        return
      }

      // 动态加载 Chart.js UMD 文件
      const script = document.createElement("script")
      script.src = "/assets/chart.js.umd.js"
      script.async = true

      script.onload = () => {
        if (typeof Chart !== "undefined") {
          chartJsLoaded = true
          resolve(Chart)
        } else {
          reject(new Error("Chart.js script loaded but Chart global not found"))
        }
      }

      script.onerror = () => {
        chartJsPromise = null // 允许重试
        reject(new Error("Failed to load Chart.js script"))
      }

      document.head.appendChild(script)
    })
  }

  return chartJsPromise
}

/**
 * 检查 Chart.js 是否已加载
 * @returns {boolean}
 */
export function isChartJsLoaded() {
  return chartJsLoaded || typeof Chart !== "undefined"
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
