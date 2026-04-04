import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown", "checkbox", "section"]
  static values = {
    page: String,
    defaultVisible: Array
  }

  connect() {
    this.loadVisibility()
    this.updateSections()
    this.closeDropdownOnOutsideClick = this.closeDropdownOnOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.closeDropdownOnOutsideClick)
  }

  toggleDropdown(event) {
    event.stopPropagation()
    const isOpen = !this.dropdownTarget.classList.contains("hidden")
    
    if (isOpen) {
      this.closeDropdown()
    } else {
      this.openDropdown()
    }
  }

  openDropdown() {
    this.dropdownTarget.classList.remove("hidden")
    document.addEventListener("click", this.closeDropdownOnOutsideClick)
  }

  closeDropdown() {
    this.dropdownTarget.classList.add("hidden")
    document.removeEventListener("click", this.closeDropdownOnOutsideClick)
  }

  closeDropdownOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.closeDropdown()
    }
  }

  toggleSection(event) {
    const sectionKey = event.target.dataset.sectionKey
    const isChecked = event.target.checked
    
    this.setVisibility(sectionKey, isChecked)
    this.updateSections()
  }

  setVisibility(sectionKey, visible) {
    const storageKey = `${this.pageValue}_visible_sections`
    let visibleSections = this.getVisibleSections()
    
    if (visible && !visibleSections.includes(sectionKey)) {
      visibleSections.push(sectionKey)
    } else if (!visible) {
      visibleSections = visibleSections.filter(s => s !== sectionKey)
    }
    
    localStorage.setItem(storageKey, JSON.stringify(visibleSections))
  }

  getVisibleSections() {
    const storageKey = `${this.pageValue}_visible_sections`
    const saved = localStorage.getItem(storageKey)
    
    if (saved) {
      try {
        return JSON.parse(saved)
      } catch (e) {
        return this.defaultVisibleValue
      }
    }
    
    return this.defaultVisibleValue
  }

  loadVisibility() {
    const visibleSections = this.getVisibleSections()
    
    this.checkboxTargets.forEach(checkbox => {
      const sectionKey = checkbox.dataset.sectionKey
      checkbox.checked = visibleSections.includes(sectionKey)
    })
  }

  updateSections() {
    const visibleSections = this.getVisibleSections()
    
    this.sectionTargets.forEach(section => {
      const sectionKey = section.dataset.sectionKey
      const isVisible = visibleSections.includes(sectionKey)
      
      if (isVisible) {
        section.classList.remove("hidden")
      } else {
        section.classList.add("hidden")
      }
    })
  }
}