import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", "searchInput", "option", "item", "selectAllBtn", "clearBtn", "confirmBtn",
    "countBadge", "hiddenCheckbox"
  ]

  static values = {
    storageKey: String,
    filterGroup: String
  }

  connect() {
    if (this.storageKeyValue) {
      this.restoreFromStorage()
    }
    this.updateButtonCount()
  }

  open() {
    this.syncToModal()
    this.modalTarget.classList.remove('hidden')
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
      this.searchInputTarget.focus()
    }
    this.updateModalCount()
  }

  close() {
    this.modalTarget.classList.add('hidden')
  }

  search(event) {
    const keyword = event.target.value.toLowerCase().trim()
    this.itemTargets.forEach(item => {
      const name = (item.dataset.name || '').toLowerCase()
      const fullName = (item.dataset.fullName || '').toLowerCase()
      const pinyin = (item.dataset.pinyin || '').toLowerCase()
      const match = name.includes(keyword) || fullName.includes(keyword) || pinyin.includes(keyword)
      item.style.display = match ? '' : 'none'
    })
  }

  selectAll() {
    this.optionTargets.forEach(cb => cb.checked = true)
    this.updateModalCount()
  }

  clearAll() {
    this.optionTargets.forEach(cb => cb.checked = false)
    this.updateModalCount()
  }

  confirm() {
    this.close()
    this.syncFromModal()
    if (this.storageKeyValue) {
      this.saveToStorage()
    }
    this.dispatchChange()
    this.updateButtonCount()
  }

  toggleOption(event) {
    this.toggleDescendants(event.target)
    this.updateModalCount()
  }

  syncToModal() {
    const hiddenCheckedIds = this.hiddenCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)

    this.optionTargets.forEach(cb => {
      cb.checked = hiddenCheckedIds.includes(cb.value)
    })
  }

  syncFromModal() {
    const selectedIds = this.optionTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)

    this.hiddenCheckboxTargets.forEach(cb => {
      cb.checked = selectedIds.includes(cb.value)
    })

    this.hiddenCheckboxTargets.forEach(cb => {
      cb.dispatchEvent(new Event('change', { bubbles: true }))
    })
  }

  getDescendantIds(parentId) {
    const descendants = []
    this.optionTargets.forEach(cb => {
      if (cb.dataset.parentId === String(parentId)) {
        descendants.push(parseInt(cb.dataset.id, 10))
        descendants.push(...this.getDescendantIds(cb.dataset.id))
      }
    })
    return descendants
  }

  toggleDescendants(cb) {
    const parentId = cb.dataset.id
    if (!parentId) return

    const descendantIds = this.getDescendantIds(parentId)
    descendantIds.forEach(id => {
      const descCb = this.modalTarget.querySelector(`[data-id="${id}"]`)
      if (descCb) descCb.checked = cb.checked
    })
  }

  updateModalCount() {
    const checked = this.optionTargets.filter(cb => cb.checked).length
    if (this.hasCountBadgeTarget) {
      this.countBadgeTarget.textContent = checked
    }
  }

  updateButtonCount() {
    const checked = this.hiddenCheckboxTargets.filter(cb => cb.checked).length
    if (this.hasCountBadgeTarget) {
      this.countBadgeTarget.textContent = checked
    }
  }

  restoreFromStorage() {
    const stored = localStorage.getItem(this.storageKeyValue)
    if (!stored) return

    const storedIds = JSON.parse(stored)
    this.hiddenCheckboxTargets.forEach(cb => {
      cb.checked = storedIds.includes(cb.value)
    })

    this.dispatch('restore', { detail: { selectedIds: storedIds } })
  }

  saveToStorage() {
    const selectedIds = this.optionTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
    localStorage.setItem(this.storageKeyValue, JSON.stringify(selectedIds))
  }

  dispatchChange() {
    const selectedIds = this.hiddenCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
    this.dispatch('change', { detail: { selectedIds } })
  }
}