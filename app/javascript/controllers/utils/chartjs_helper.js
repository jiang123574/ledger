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
