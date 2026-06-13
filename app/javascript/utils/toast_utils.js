// Toast notification utilities
// Provides consistent toast notification functions for the application

/**
 * Show a toast notification
 * @param {string} message - The message to display
 * @param {string} type - 'success' | 'error' | 'info' (default 'info')
 * @param {number} duration - Duration in milliseconds (default 2500)
 */
export function showToast(message, type = 'info', duration = 2500) {
  const colorMap = {
    success: 'bg-green-500 text-white',
    error: 'bg-red-500 text-white',
    info: 'bg-surface dark:bg-surface-dark text-primary'
  }
  const toast = document.createElement('div')
  toast.className = `fixed top-4 right-4 px-4 py-2 rounded-lg shadow-lg z-50 ${colorMap[type] || colorMap.info}`
  toast.textContent = message
  document.body.appendChild(toast)
  setTimeout(() => {
    toast.style.opacity = '0'
    toast.style.transition = 'opacity 0.3s'
    setTimeout(() => toast.remove(), 300)
  }, duration)
}

/**
 * Show a success toast notification
 * @param {string} message - The message to display
 * @param {number} duration - Duration in milliseconds (default 2000)
 */
export function showSuccessToast(message, duration = 2000) {
  showToast(message, 'success', duration)
}

/**
 * Show an error toast notification
 * @param {string} message - The message to display
 * @param {number} duration - Duration in milliseconds (default 3000)
 */
export function showErrorToast(message, duration = 3000) {
  showToast(message, 'error', duration)
}

/**
 * Show an info toast notification
 * @param {string} message - The message to display
 * @param {number} duration - Duration in milliseconds (default 2500)
 */
export function showInfoToast(message, duration = 2500) {
  showToast(message, 'info', duration)
}