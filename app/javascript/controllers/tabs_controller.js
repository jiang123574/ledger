import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {
    activeTab: String,
    urlParamKey: String
  }

  connect() {
    this.loadFromUrl()
    this.activateTab(this.activeTabValue || this.tabTargets[0]?.dataset.tab)
  }

  loadFromUrl() {
    const urlParamKey = this.urlParamKeyValue
    if (!urlParamKey) return

    const params = new URLSearchParams(window.location.search)
    const tabFromUrl = params.get(urlParamKey)
    
    if (tabFromUrl) {
      this.activeTabValue = tabFromUrl
    }
  }

  selectTab(event) {
    event.preventDefault()
    const tab = event.currentTarget
    const tabId = tab.dataset.tab
    
    this.activateTab(tabId)
    this.updateUrl(tabId)
  }

  activateTab(tabId) {
    this.tabTargets.forEach(tab => {
      if (tab.dataset.tab === tabId) {
        tab.classList.add("border-b-2", "border-blue-600", "text-blue-600")
        tab.classList.remove("text-gray-500", "hover:text-gray-700")
      } else {
        tab.classList.remove("border-b-2", "border-blue-600", "text-blue-600")
        tab.classList.add("text-gray-500", "hover:text-gray-700")
      }
    })

    this.panelTargets.forEach(panel => {
      if (panel.dataset.tabPanel === tabId) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })

    this.activeTabValue = tabId
  }

  updateUrl(tabId) {
    const urlParamKey = this.urlParamKeyValue
    if (!urlParamKey) return

    const url = new URL(window.location)
    if (tabId) {
      url.searchParams.set(urlParamKey, tabId)
    } else {
      url.searchParams.delete(urlParamKey)
    }
    
    history.replaceState(null, "", url)
  }
}
