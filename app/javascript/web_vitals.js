// Core Web Vitals Monitoring
// Tracks LCP, FID, CLS and reports to analytics

class WebVitalsMonitor {
  constructor() {
    this.metrics = {}
    this.init()
  }

  init() {
    this.observeLCP()
    this.observeFID()
    this.observeCLS()
    this.observeFCP()
    this.observeTTFB()
  }

  // Largest Contentful Paint
  observeLCP() {
    if (!PerformanceObserver) return

    try {
      const observer = new PerformanceObserver((list) => {
        const entries = list.getEntries()
        const lastEntry = entries[entries.length - 1]
        
        this.metrics.lcp = {
          value: lastEntry.renderTime || lastEntry.loadTime,
          element: lastEntry.element?.tagName,
          url: lastEntry.url,
          rating: this.rateLCP(lastEntry.renderTime || lastEntry.loadTime)
        }
        
        this.report('lcp', this.metrics.lcp)
      })
      
      observer.observe({ type: 'largest-contentful-paint', buffered: true })
    } catch (e) {
      console.warn('LCP observer not supported')
    }
  }

  // First Input Delay
  observeFID() {
    if (!PerformanceObserver) return

    try {
      const observer = new PerformanceObserver((list) => {
        list.getEntries().forEach((entry) => {
          this.metrics.fid = {
            value: entry.processingStart - entry.startTime,
            eventType: entry.name,
            rating: this.rateFID(entry.processingStart - entry.startTime)
          }
          
          this.report('fid', this.metrics.fid)
        })
      })
      
      observer.observe({ type: 'first-input', buffered: true })
    } catch (e) {
      console.warn('FID observer not supported')
    }
  }

  // Cumulative Layout Shift
  observeCLS() {
    if (!PerformanceObserver) return

    let clsValue = 0
    let clsEntries = []

    try {
      const observer = new PerformanceObserver((list) => {
        list.getEntries().forEach((entry) => {
          if (!entry.hadRecentInput) {
            clsValue += entry.value
            clsEntries.push(entry)
          }
        })
      })
      
      observer.observe({ type: 'layout-shift', buffered: true })

      // Report CLS on page hide
      addEventListener('pagehide', () => {
        this.metrics.cls = {
          value: clsValue,
          entries: clsEntries.length,
          rating: this.rateCLS(clsValue)
        }
        
        this.report('cls', this.metrics.cls)
      })
    } catch (e) {
      console.warn('CLS observer not supported')
    }
  }

  // First Contentful Paint
  observeFCP() {
    if (!PerformanceObserver) return

    try {
      const observer = new PerformanceObserver((list) => {
        list.getEntries().forEach((entry) => {
          if (entry.name === 'first-contentful-paint') {
            this.metrics.fcp = {
              value: entry.startTime,
              rating: this.rateFCP(entry.startTime)
            }
            
            this.report('fcp', this.metrics.fcp)
          }
        })
      })
      
      observer.observe({ type: 'paint', buffered: true })
    } catch (e) {
      console.warn('FCP observer not supported')
    }
  }

  // Time to First Byte
  observeTTFB() {
    const navigationEntry = performance.getEntriesByType('navigation')[0]
    
    if (navigationEntry) {
      this.metrics.ttfb = {
        value: navigationEntry.responseStart - navigationEntry.requestStart,
        dnsTime: navigationEntry.domainLookupEnd - navigationEntry.domainLookupStart,
        tcpTime: navigationEntry.connectEnd - navigationEntry.connectStart,
        rating: this.rateTTFB(navigationEntry.responseStart - navigationEntry.requestStart)
      }
      
      this.report('ttfb', this.metrics.ttfb)
    }
  }

  // Rating thresholds based on Google's recommendations
  rateLCP(value) {
    if (value <= 2500) return 'good'
    if (value <= 4000) return 'needs-improvement'
    return 'poor'
  }

  rateFID(value) {
    if (value <= 100) return 'good'
    if (value <= 300) return 'needs-improvement'
    return 'poor'
  }

  rateCLS(value) {
    if (value <= 0.1) return 'good'
    if (value <= 0.25) return 'needs-improvement'
    return 'poor'
  }

  rateFCP(value) {
    if (value <= 1800) return 'good'
    if (value <= 3000) return 'needs-improvement'
    return 'poor'
  }

  rateTTFB(value) {
    if (value <= 800) return 'good'
    if (value <= 1800) return 'needs-improvement'
    return 'poor'
  }

  // Report metrics (send to analytics or console)
  report(name, metric) {
    // Log to console in development
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
      console.log(`[WebVitals] ${name}:`, metric)
    }

    // Send to analytics endpoint (if available)
    if (navigator.sendBeacon && window.location.hostname !== 'localhost') {
      const data = new Blob(
        [JSON.stringify({ metric: name, ...metric, url: window.location.href })],
        { type: 'application/json' }
      )
      navigator.sendBeacon('/api/vitals', data)
    }

    // Store in localStorage for debugging
    const stored = JSON.parse(localStorage.getItem('webVitals') || '[]')
    stored.push({ name, ...metric, timestamp: Date.now() })
    // Keep only last 50 entries
    if (stored.length > 50) stored.shift()
    localStorage.setItem('webVitals', JSON.stringify(stored))
  }

  // Get all collected metrics
  getMetrics() {
    return this.metrics
  }
}

// Initialize on page load
window.webVitalsMonitor = new WebVitalsMonitor()

// Export for Stimulus or other modules
export { WebVitalsMonitor }