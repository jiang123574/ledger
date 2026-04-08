import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.debounceTimer = null
    this.setupEventListeners()
  }

  setupEventListeners() {
    this.element.querySelectorAll("input, select, textarea").forEach((input) => {
      const eventType = this.getEventType(input)
      input.addEventListener(eventType, this.handleInput.bind(this))
    })
  }

  getEventType(input) {
    const type = input.type?.toLowerCase() || input.tagName.toLowerCase()

    switch (type) {
      case "text":
      case "email":
      case "search":
        return "blur-sm"
      case "number":
      case "date":
      case "datetime-local":
      case "time":
        return "change"
      case "checkbox":
      case "radio":
        return "change"
      case "range":
        return "input"
      case "select":
        return "change"
      case "textarea":
        return "blur-sm"
      default:
        return "change"
    }
  }

  handleInput(event) {
    const input = event.target
    const debounceTime = this.getDebounceTime(input)

    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    if (debounceTime === 0) {
      this.submitForm()
    } else {
      this.debounceTimer = setTimeout(() => {
        this.submitForm()
      }, debounceTime)
    }
  }

  getDebounceTime(input) {
    const type = input.type?.toLowerCase() || input.tagName.toLowerCase()

    switch (type) {
      case "text":
      case "email":
      case "search":
      case "textarea":
        return 500
      case "number":
      case "date":
      case "datetime-local":
      case "time":
        return 0
      case "checkbox":
      case "radio":
        return 0
      case "range":
        return 200
      case "select":
        return 0
      default:
        return 0
    }
  }

  submitForm() {
    if (this.element.requestSubmit) {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }
}
