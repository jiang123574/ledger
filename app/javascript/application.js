// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

import "@hotwired/turbo-rails"
import "controllers"
import "bill_formatters"
import "web_vitals"
import "selectors"
import { installAmountExpressionSupport, INVALID_AMOUNT_MESSAGE } from "amount_expression"
import { showErrorToast } from "utils/toast_utils"

// 金额输入框支持 12.5+3 这类简单加减法
installAmountExpressionSupport({
  onInvalid: () => showErrorToast(INVALID_AMOUNT_MESSAGE)
})

// Register PWA service worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker.js')
      .then(reg => console.log('Service Worker registered:', reg.scope))
      .catch(err => console.warn('Service Worker registration failed:', err))
  })
}
