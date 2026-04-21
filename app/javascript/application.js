// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

import "@hotwired/turbo-rails"
import "controllers"
import "bill_formatters"
import "web_vitals"
import "selectors"

// Disable Chart.js touchmove to avoid passive event listener warning
// Keep tooltip interaction on click/touchstart/touchend, but disable drag
if (typeof Chart !== 'undefined') {
  Chart.defaults.options.events = ['mousemove', 'mouseout', 'click', 'touchstart', 'touchend']
}

// Register PWA service worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker.js')
      .then(reg => console.log('Service Worker registered:', reg.scope))
      .catch(err => console.warn('Service Worker registration failed:', err))
  })
}
