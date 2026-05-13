// Entry list utilities
// Provides functions for manipulating entry list display

import { createEntryCard } from "entry_card_renderer"

/**
 * Insert an entry card to the list container
 * @param {Object} entry - The entry data
 * @param {Object} options - Options including onEdit, onDelete callbacks
 * @param {string} containerId - The container element ID (default 'transactions-container')
 */
export function insertEntryToList(entry, options = {}, containerId = 'transactions-container') {
  const container = document.querySelector(`#${containerId}`)
  if (!container || !entry) return

  const cardFragment = createEntryCard(entry, options)
  container.insertBefore(cardFragment, container.firstChild)

  addHighlightAnimation(container, entry.id)
}

/**
 * Insert multiple entries to the list
 * @param {Array} entries - Array of entry data
 * @param {Object} options - Options including onEdit, onDelete callbacks
 * @param {string} containerId - The container element ID
 */
export function insertEntriesToList(entries, options = {}, containerId = 'transactions-container') {
  if (!entries || entries.length === 0) return

  entries.forEach(entry => {
    insertEntryToList(entry, options, containerId)
  })
}

/**
 * Insert an entry to the bill entries container
 * @param {Object} entry - The entry data
 * @param {Object} options - Options including onEdit, onDelete callbacks
 */
export function insertEntryToBillContainer(entry, options = {}) {
  insertEntryToList(entry, options, 'bill-entries-container')
}

/**
 * Remove an entry from the list with animation
 * @param {string} id - The entry ID to remove
 */
export function removeEntryFromList(id) {
  const containers = [
    document.querySelector('#transactions-container'),
    document.querySelector('#bill-entries-container'),
    document.querySelector('[data-detail-container]')
  ].filter(c => c)

  containers.forEach(container => {
    const elementsToRemove = []

    // Desktop row
    const desktopRow = container.querySelector(`[data-entry-id="${id}"]`)
    if (desktopRow) elementsToRemove.push(desktopRow)

    // Mobile card
    const mobileRow = container.querySelector(`[data-mobile-entry-id="${id}"]`)
    if (mobileRow) elementsToRemove.push(mobileRow)

    // Add animation
    elementsToRemove.forEach(el => {
      el.style.transition = 'opacity 0.2s, height 0.3s, padding 0.3s, margin 0.3s'
      el.style.opacity = '0'
      el.style.height = '0'
      el.style.padding = '0'
      el.style.margin = '0'
      el.style.overflow = 'hidden'
    })

    // Remove after animation
    setTimeout(() => {
      elementsToRemove.forEach(el => el.remove())
    }, 300)
  })
}

/**
 * Add highlight animation to newly added entry
 * @param {HTMLElement} container - The container element
 * @param {string} entryId - The entry ID
 * @param {number} duration - Animation duration in milliseconds (default 2000)
 */
export function addHighlightAnimation(container, entryId, duration = 2000) {
  const desktopRow = container.querySelector(`[data-entry-id="${entryId}"]`)
  const mobileRow = container.querySelector(`[data-mobile-entry-id="${entryId}"]`)

  if (desktopRow) {
    desktopRow.classList.add('bg-blue-50', 'dark:bg-blue-900/20')
    setTimeout(() => {
      desktopRow.classList.remove('bg-blue-50', 'dark:bg-blue-900/20')
    }, duration)
  }

  if (mobileRow) {
    mobileRow.classList.add('bg-blue-50', 'dark:bg-blue-900/20')
    setTimeout(() => {
      mobileRow.classList.remove('bg-blue-50', 'dark:bg-blue-900/20')
    }, duration)
  }
}

/**
 * Get bill-statement controller instance
 * @returns {Object|null} The controller instance or null
 */
export function getBillStatementController() {
  const element = document.querySelector('[data-controller="bill-statement"]')
  if (element && window.Stimulus) {
    return window.Stimulus.getControllerForElementAndIdentifier(element, 'bill-statement')
  }
  return null
}