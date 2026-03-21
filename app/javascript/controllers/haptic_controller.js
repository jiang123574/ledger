import { Controller } from "@hotwired/stimulus"

// Haptic Feedback Controller
// Provides tactile feedback for touch interactions

export default class extends Controller {
  static values = {
    pattern: { type: String, default: "10" },  // vibration pattern in ms
    enabled: { type: Boolean, default: true }
  }

  connect() {
    // Check if vibration API is supported
    this.hasVibration = 'vibrate' in navigator
    
    // Add touch feedback class
    if (this.hasVibration && this.enabledValue) {
      this.element.classList.add('touch-feedback-active')
    }
  }

  // Trigger vibration on touch/click
  feedback(event) {
    if (!this.hasVibration || !this.enabledValue) return
    
    const pattern = this.parsePattern()
    navigator.vibrate(pattern)
  }

  // Light tap feedback (10ms)
  light(event) {
    if (this.hasVibration) {
      navigator.vibrate(10)
    }
  }

  // Medium feedback (25ms)
  medium(event) {
    if (this.hasVibration) {
      navigator.vibrate(25)
    }
  }

  // Heavy feedback (50ms)
  heavy(event) {
    if (this.hasVibration) {
      navigator.vibrate(50)
    }
  }

  // Success pattern: short-short
  success(event) {
    if (this.hasVibration) {
      navigator.vibrate([10, 50, 10])
    }
  }

  // Error pattern: long
  error(event) {
    if (this.hasVibration) {
      navigator.vibrate([50, 30, 50, 30, 50])
    }
  }

  // Parse pattern value
  parsePattern() {
    try {
      const parts = this.patternValue.split(',').map(p => parseInt(p.trim(), 10))
      return parts.length === 1 ? parts[0] : parts
    } catch {
      return 10
    }
  }

  // Toggle vibration on/off
  toggle() {
    this.enabledValue = !this.enabledValue
    localStorage.setItem('hapticFeedback', this.enabledValue)
  }
}