// Selector factory utilities
// Provides factory functions for initializing selectors consistently

import { initSelectorWithData } from "selectors"

/**
 * Create a category selector
 * @param {Object} options - Configuration options
 * @param {Array} options.dataSource - Array of category data
 * @param {Function} options.onSelect - Callback when category is selected
 */
export function createCategorySelector(options = {}) {
  const dataSource = options.dataSource || []
  const onSelect = options.onSelect || (() => {})

  initSelectorWithData({
    searchInputId: 'category-search-input',
    dropdownId: 'category-dropdown',
    optionsId: 'category-options',
    hiddenInputId: 'new_transaction_category_id',
    dataSource: dataSource,
    noMatchText: '无匹配分类',
    enableLevelIndent: true,
    onSelect: (value, item) => {
      if (item && item.type) {
        onSelect(item.type, item)
      }
    }
  })
}

/**
 * Create an account selector for income
 * @param {Object} options - Configuration options
 * @param {Array} options.dataSource - Array of account data
 */
export function createIncomeAccountSelector(options = {}) {
  const dataSource = options.dataSource || []

  initSelectorWithData({
    searchInputId: 'account-search-input-income',
    dropdownId: 'account-dropdown-income',
    optionsId: 'account-options-income',
    hiddenInputId: 'transaction_account_id_income',
    dataSource: dataSource,
    noMatchText: '无匹配账户'
  })
}

/**
 * Create transfer source and target selectors
 * @param {Object} options - Configuration options
 * @param {Array} options.dataSource - Array of account data
 */
export function createTransferSelectors(options = {}) {
  const dataSource = options.dataSource || []

  // Source account selector
  initSelectorWithData({
    searchInputId: 'account-search-input',
    dropdownId: 'account-dropdown',
    optionsId: 'account-options',
    hiddenInputId: 'transaction_account_id',
    dataSource: dataSource,
    noMatchText: '无匹配账户'
  })

  // Target account selector
  initSelectorWithData({
    searchInputId: 'target-account-search-input',
    dropdownId: 'target-account-dropdown',
    optionsId: 'target-account-options',
    hiddenInputId: 'target_account_id',
    dataSource: dataSource,
    noMatchText: '无匹配账户'
  })
}

/**
 * Create funding account selector (for expense with funding source)
 * @param {Object} options - Configuration options
 * @param {Array} options.dataSource - Array of account data
 */
export function createFundingAccountSelector(options = {}) {
  const dataSource = options.dataSource || []

  initSelectorWithData({
    searchInputId: 'funding-account-search-input',
    dropdownId: 'funding-account-dropdown',
    optionsId: 'funding-account-options',
    hiddenInputId: 'funding_account_id',
    dataSource: dataSource,
    noMatchText: '无匹配账户',
    emptyOption: { label: '不补记资金来源', value: '', display: '' }
  })
}

/**
 * Force reinitialize selectors by resetting the selectorBound flag
 * Used when switching between modes (category/transfer)
 */
export function forceInitTransferSelectors(dataSource) {
  const sourceSearch = document.getElementById('account-search-input')
  const targetSearch = document.getElementById('target-account-search-input')

  if (sourceSearch) sourceSearch.dataset.selectorBound = 'false'
  if (targetSearch) targetSearch.dataset.selectorBound = 'false'

  createTransferSelectors({ dataSource })
}