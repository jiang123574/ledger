import { Controller } from "@hotwired/stimulus"
import { initSelectorWithData } from "selectors"

export default class extends Controller {
  static targets = [
    "modal", "form", "descriptionInput", "dateInput", "amountInput",
    "categoryHidden", "categorySearchInput", "categoryDropdown",
    "accountHidden", "accountSearchInput", "accountDropdown",
    "fundingAccountHidden", "fundingAccountSearchInput", "fundingAccountDropdown",
    "counterpartySelect", "noteInput"
  ]

  connect() {
    this.allAccounts = this.loadDataSource('accounts-data', [])
    this.allCategories = this.loadDataSource('modal-categories-data', [])

    // 转换分类数据格式
    this.categoryData = this.allCategories.map(cat => ({
      id: cat.name,
      name: cat.name,
      full_name: cat.full_name || cat.name,
      pinyin: cat.pinyin || ''
    }))

    // 暴露全局函数供快捷键调用
    window.openNewReceivableModal = this.open.bind(this)
  }

  disconnect() {
    window.openNewReceivableModal = undefined
  }

  loadDataSource(id, defaultVal) {
    const el = document.getElementById(id)
    if (el && el.textContent) {
      try {
        defaultVal = JSON.parse(el.textContent)
      } catch (e) {
        console.error(`Error parsing ${id}:`, e)
      }
    }
    return defaultVal
  }

  open() {
    this.resetForm()
    this.initSelectors()
    this.element.classList.remove('hidden')
  }

  close() {
    this.element.classList.add('hidden')
  }

  resetForm() {
    if (this.hasFormTarget) this.formTarget.reset()
    if (this.hasDateInputTarget) this.dateInputTarget.value = new Date().toISOString().split('T')[0]
    if (this.hasCategoryHiddenTarget) this.categoryHiddenTarget.value = ''
    if (this.hasCategorySearchInputTarget) this.categorySearchInputTarget.value = ''
    if (this.hasAccountHiddenTarget) this.accountHiddenTarget.value = ''
    if (this.hasAccountSearchInputTarget) this.accountSearchInputTarget.value = ''
    if (this.hasFundingAccountHiddenTarget) this.fundingAccountHiddenTarget.value = ''
    if (this.hasFundingAccountSearchInputTarget) this.fundingAccountSearchInputTarget.value = ''
  }

  initSelectors() {
    // 账户选择器
    initSelectorWithData({
      searchInputId: 'new-receivable-account-search',
      dropdownId: 'new-receivable-account-dropdown',
      optionsId: 'new-receivable-account-options',
      hiddenInputId: 'new-receivable-account-id',
      dataSource: this.allAccounts,
      noMatchText: '无匹配账户'
    })

    // 分类选择器
    initSelectorWithData({
      searchInputId: 'new-receivable-category-search',
      dropdownId: 'new-receivable-category-dropdown',
      optionsId: 'new-receivable-category-options',
      hiddenInputId: 'new-receivable-category-id',
      dataSource: this.categoryData,
      emptyOption: { label: '不设置分类', value: '', display: '' },
      noMatchText: '无匹配分类'
    })

    // 资金来源选择器
    initSelectorWithData({
      searchInputId: 'new-receivable-funding-account-search',
      dropdownId: 'new-receivable-funding-account-dropdown',
      optionsId: 'new-receivable-funding-account-options',
      hiddenInputId: 'new-receivable-funding-account-id',
      dataSource: this.allAccounts,
      noMatchText: '无匹配账户'
    })
  }
}