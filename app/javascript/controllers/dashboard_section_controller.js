import { Controller } from "@hotwired/stimulus";

// Dashboard Section - Handles collapsible sections with localStorage persistence
export default class extends Controller {
  static targets = ["content", "chevron", "button"];
  static values = {
    sectionKey: String,
    collapsed: { type: Boolean, default: false }
  };

  connect() {
    // Load collapsed state from localStorage
    const savedState = localStorage.getItem(`dashboard_section_${this.sectionKeyValue}`);
    if (savedState !== null) {
      this.collapsedValue = savedState === "true";
    }
    this.updateUI();
  }

  toggle(event) {
    event.preventDefault();
    this.collapsedValue = !this.collapsedValue;
    this.saveState();
    this.updateUI();
  }

  handleToggleKeydown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.toggle(event);
    }
  }

  saveState() {
    localStorage.setItem(`dashboard_section_${this.sectionKeyValue}`, this.collapsedValue.toString());
  }

  updateUI() {
    if (this.collapsedValue) {
      this.contentTarget.classList.add("hidden");
      if (this.hasChevronTarget) {
        this.chevronTarget.classList.add("-rotate-90");
      }
      if (this.hasButtonTarget) {
        this.buttonTarget.setAttribute("aria-expanded", "false");
      }
    } else {
      this.contentTarget.classList.remove("hidden");
      if (this.hasChevronTarget) {
        this.chevronTarget.classList.remove("-rotate-90");
      }
      if (this.hasButtonTarget) {
        this.buttonTarget.setAttribute("aria-expanded", "true");
      }
    }
  }
}