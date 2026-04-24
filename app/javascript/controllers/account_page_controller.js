import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "accountList", "accountToggleIcon", "periodValueDisplay",
    "periodPickerPanel", "pickerYearDisplay", "pickerGrid",
    "periodValueContainer", "searchInput", "periodTypeFilter",
    "periodValueFilter", "typeFilter", "categoryFilterModal"
  ]

  static values = {
    accountId: String,
    selectedCategoryIds: Array,
    currentPage: Number,
    pickerYear: Number
  }

  connect() {
    this.pickerYearValue = new Date().getFullYear()
    this.pickerPanelOpen = false
    this.isComposing = false

    // 从 URL 参数初始化 selectedCategoryIds
    const urlParams = new URLSearchParams(window.location.search)
    window.selectedCategoryIds = urlParams.getAll('category_ids[]').filter(id => id)

    this._boundCategoryFilterChange = this.handleCategoryFilterChange.bind(this)
    document.addEventListener('category-filter:change', this._boundCategoryFilterChange)

    this.bindEvents()
    this.syncPeriodInputType()
    this.updatePeriodValueDisplay()
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
    document.removeEventListener('category-filter:change', this._boundCategoryFilterChange)
  }

  handleCategoryFilterChange(event) {
    const selectedIds = event.detail?.selectedIds || []
    window.selectedCategoryIds = selectedIds
    this.applyFilters()
  }

  bindEvents() {
    const searchInput = document.getElementById('search-input')
    if (searchInput) {
      searchInput.addEventListener('compositionstart', () => this.isComposing = true)
      searchInput.addEventListener('compositionend', () => {
        this.isComposing = false
        this.debouncedApplyFilters()
      })
      searchInput.addEventListener('input', () => {
        if (this.isComposing) return
        this.debouncedApplyFilters()
      })
      searchInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !this.isComposing) {
          this.applyFilters()
        }
      })
    }

    const periodTypeFilter = document.getElementById('period-type-filter')
    if (periodTypeFilter) {
      periodTypeFilter.addEventListener('change', () => {
        this.syncPeriodInputType()
        this.applyFilters()
      })
    }

    const typeFilter = document.getElementById('type-filter')
    if (typeFilter) {
      typeFilter.addEventListener('change', () => this.applyFilters())
    }
  }

  toggleShowHidden() {
    const params = new URLSearchParams(window.location.search)
    if (params.get('show_hidden') === 'true') {
      params.delete('show_hidden')
    } else {
      params.set('show_hidden', 'true')
    }
    window.location.href = '/accounts' + (params.toString() ? '?' + params.toString() : '')
  }

  toggleAccountList() {
    const list = document.getElementById('account-list')
    const icon = document.getElementById('account-toggle-icon')
    if (list) {
      if (list.classList.contains('hidden')) {
        list.classList.remove('hidden')
        if (icon) icon.style.transform = 'rotate(180deg)'
      } else {
        list.classList.add('hidden')
        if (icon) icon.style.transform = 'rotate(0deg)'
      }
    }
  }

  filterByAccount(event) {
    const id = event.params?.accountId || event.currentTarget.dataset.accountId
    const params = new URLSearchParams(window.location.search)
    params.set('account_id', id)
    history.pushState({}, '', '/accounts?' + params.toString())
    this.refreshMainContent('/accounts?' + params.toString())
    this.updateAccountHighlight(id)
    this.collapseAccountListOnMobile()
  }

  viewAllTransactions() {
    const params = new URLSearchParams(window.location.search)
    params.delete('account_id')
    const url = '/accounts' + (params.toString() ? '?' + params.toString() : '')
    history.pushState({}, '', url)
    this.refreshMainContent(url)
    this.updateAccountHighlight(null)
    this.collapseAccountListOnMobile()
  }

  clearFilters() {
    const params = new URLSearchParams(window.location.search)
    const accountId = params.get('account_id')
    params.delete('search')
    params.delete('type')
    params.delete('period_type')
    params.delete('period_value')
    params.delete('category_ids')
    if (accountId) params.set('account_id', accountId)
    const url = '/accounts' + (params.toString() ? '?' + params.toString() : '')
    history.pushState({}, '', url)
    this.refreshMainContent(url)
  }

  collapseAccountListOnMobile() {
    if (window.innerWidth < 1024) {
      const list = document.getElementById('account-list')
      const icon = document.getElementById('account-toggle-icon')
      if (list && !list.classList.contains('hidden')) {
        list.classList.add('hidden')
        if (icon) icon.style.transform = 'rotate(0deg)'
      }
    }
  }

  updateAccountHighlight(accountId) {
    document.querySelectorAll('.account-drag-item').forEach(item => {
      item.classList.remove('bg-surface-inset', 'dark:bg-surface-dark-inset')
    })
    if (accountId) {
      const item = document.querySelector(`.account-drag-item[data-account-id="${accountId}"]`)
      if (item) item.classList.add('bg-surface-inset', 'dark:bg-surface-dark-inset')
    }
  }

  async refreshMainContent(url) {
    try {
      const mainContent = document.querySelector('[data-account-page] > div:nth-child(2)')
      if (mainContent) mainContent.style.opacity = '0.5'

      const response = await fetch(url)
      const html = await response.text()
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')

      const newMainContent = doc.querySelector('[data-account-page] > div:nth-child(2)')
      if (mainContent && newMainContent) {
        mainContent.innerHTML = newMainContent.innerHTML
      }

      const creditBillWrapper = document.querySelector('[data-account-page] > div:nth-child(3)')
      const newCreditBillWrapper = doc.querySelector('[data-account-page] > div:nth-child(3)')
      if (creditBillWrapper && newCreditBillWrapper) {
        creditBillWrapper.outerHTML = newCreditBillWrapper.outerHTML
      }

      if (mainContent) mainContent.style.opacity = '1'

      setTimeout(() => this.reinitializePageScripts(), 50)
    } catch (error) {
      console.error('刷新内容失败:', error)
      window.location.href = url
    }
  }

  reinitializePageScripts() {
    const entryListEl = document.getElementById('transaction-list')
    if (entryListEl && window.Stimulus) {
      const controller = window.Stimulus.getControllerForElementAndIdentifier(entryListEl, 'entry-list')
      if (controller) {
        controller.disconnect()
        controller.connect()
      }
    }

    if (typeof window.initCreditBills === 'function') {
      const wrapper = document.getElementById('credit-bill-wrapper')
      if (wrapper && wrapper.dataset.billStatementAccountIdValue) {
        window.initCreditBills()
      }
    }

    this.syncPeriodInputType()
    this.bindEvents()
  }

  applyFilters() {
    const params = new URLSearchParams()
    const searchInput = document.getElementById('search-input')
    const typeFilter = document.getElementById('type-filter')
    const periodTypeFilter = document.getElementById('period-type-filter')
    const periodValueFilter = document.getElementById('period-value-filter')
    const urlParams = new URLSearchParams(window.location.search)

    const search = searchInput?.value || ''
    const type = typeFilter?.value || ''
    const periodType = periodTypeFilter?.value || ''
    const periodValue = periodValueFilter?.value || ''
    const accountId = urlParams.get('account_id') || this.accountIdValue

    if (search) params.append('search', search)
    if (type) params.append('type', type)
    if (periodType && periodType !== 'all') {
      params.append('period_type', periodType)
      if (periodValue) params.append('period_value', periodValue)
    } else if (periodType === 'all') {
      params.append('period_type', 'all')
    }

    const selectedCategoryIds = window.selectedCategoryIds || []
    selectedCategoryIds.forEach(id => params.append('category_ids[]', id))

    if (accountId) params.append('account_id', accountId)

    const url = '/accounts?' + params.toString()
    history.pushState({}, '', url)
    this.refreshMainContent(url)
  }

  debouncedApplyFilters() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.applyFilters(), 500)
  }

  syncPeriodInputType() {
    const periodTypeEl = document.getElementById('period-type-filter')
    const periodValueEl = document.getElementById('period-value-filter')
    const periodValueContainer = document.getElementById('period-value-container')
    if (!periodTypeEl || !periodValueEl) return

    const periodType = periodTypeEl.value

    if (periodType === 'all') {
      if (periodValueContainer) periodValueContainer.style.display = 'none'
      return
    } else {
      if (periodValueContainer) periodValueContainer.style.display = ''
    }

    const today = new Date()

    if (periodType === 'week') {
      if (!periodValueEl.value || !/^\d{4}-W\d{2}$/.test(periodValueEl.value)) {
        const temp = new Date(today.getTime())
        temp.setDate(temp.getDate() + 3 - ((temp.getDay() + 6) % 7))
        const weekYear = temp.getFullYear()
        const firstThursday = new Date(weekYear, 0, 4)
        const weekNumber = Math.ceil((((temp - firstThursday) / 86400000) + firstThursday.getDay() + 1) / 7)
        periodValueEl.value = `${weekYear}-W${String(weekNumber).padStart(2, '0')}`
      }
    } else if (periodType === 'year') {
      // 从现有值提取年份（支持 YYYY, YYYY-MM, YYYY-Wxx 格式）
      let yearValue
      const monthMatch = periodValueEl.value.match(/^(\d{4})-\d{2}$/)
      const weekMatch = periodValueEl.value.match(/^(\d{4})-W\d{2}$/)
      if (monthMatch) {
        yearValue = parseInt(monthMatch[1], 10)
      } else if (weekMatch) {
        yearValue = parseInt(weekMatch[1], 10)
      } else {
        yearValue = parseInt(periodValueEl.value, 10)
      }
      if (!yearValue || yearValue < 2000 || yearValue > 2100) {
        yearValue = today.getFullYear()
      }
      periodValueEl.value = String(yearValue)
    } else {
      if (!/^\d{4}-\d{2}$/.test(periodValueEl.value)) {
        periodValueEl.value = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`
      }
    }
    this.updatePeriodValueDisplay()
  }

  updatePeriodValueDisplay() {
    const periodTypeEl = document.getElementById('period-type-filter')
    const periodValueEl = document.getElementById('period-value-filter')
    const displayEl = document.getElementById('period-value-display')
    if (!periodTypeEl || !periodValueEl || !displayEl) return

    displayEl.textContent = this.formatPeriodValue(periodValueEl.value, periodTypeEl.value)
  }

  formatPeriodValue(value, type) {
    if (type === 'year') {
      return value + '年'
    } else if (type === 'month') {
      const match = value.match(/^(\d{4})-(\d{2})$/)
      if (match) {
        return match[1] + '年' + parseInt(match[2]) + '月'
      }
      return value
    } else if (type === 'week') {
      const match = value.match(/^(\d{4})-W(\d{2})$/)
      if (match) {
        return match[1] + '年 第' + parseInt(match[2]) + '周'
      }
      return value
    }
    return value
  }

  shiftPeriod(event) {
    const direction = event.params?.direction || parseInt(event.currentTarget.dataset.direction) || 0
    const periodTypeEl = document.getElementById('period-type-filter')
    const periodValueEl = document.getElementById('period-value-filter')
    if (!periodTypeEl || !periodValueEl) return

    const periodType = periodTypeEl.value
    let value = periodValueEl.value

    if (periodType === 'month') {
      const match = value.match(/^(\d{4})-(\d{2})$/)
      if (match) {
        let year = parseInt(match[1])
        let month = parseInt(match[2])
        if (direction === -1) {
          month -= 1
          if (month < 1) { month = 12; year -= 1 }
        } else {
          month += 1
          if (month > 12) { month = 1; year += 1 }
        }
        periodValueEl.value = `${year}-${String(month).padStart(2, '0')}`
      }
    } else if (periodType === 'year') {
      let year = parseInt(value)
      year += direction
      periodValueEl.value = String(year)
    } else if (periodType === 'week') {
      const match = value.match(/^(\d{4})-W(\d{2})$/)
      if (match) {
        let year = parseInt(match[1])
        let week = parseInt(match[2])
        if (direction === -1) {
          week -= 1
          if (week < 1) { week = 52; year -= 1 }
        } else {
          week += 1
          if (week > 52) { week = 1; year += 1 }
        }
        periodValueEl.value = `${year}-W${String(week).padStart(2, '0')}`
      }
    }

    this.updatePeriodValueDisplay()
    this.applyFilters()
  }

  togglePeriodPicker() {
    const panel = document.getElementById('period-picker-panel')
    if (!panel) return

    if (this.pickerPanelOpen) {
      this.closePeriodPicker()
    } else {
      this.openPeriodPickerPanel()
    }
  }

  openPeriodPickerPanel() {
    const panel = document.getElementById('period-picker-panel')
    const periodTypeEl = document.getElementById('period-type-filter')
    const periodValueEl = document.getElementById('period-value-filter')
    if (!panel || !periodTypeEl) return

    const periodType = periodTypeEl.value
    const currentValue = periodValueEl.value

    if (periodType === 'month') {
      const parts = currentValue.split('-')
      this.pickerYearValue = parseInt(parts[0]) || new Date().getFullYear()
      this.renderMonthPicker()
    } else if (periodType === 'year') {
      this.pickerYearValue = parseInt(currentValue) || new Date().getFullYear()
      this.renderYearPicker()
    }

    panel.classList.remove('hidden')
    this.pickerPanelOpen = true
  }

  closePeriodPicker() {
    const panel = document.getElementById('period-picker-panel')
    if (panel) panel.classList.add('hidden')
    this.pickerPanelOpen = false
  }

  shiftPickerYear(event) {
    const direction = event.params?.direction || parseInt(event.currentTarget.dataset.direction) || 0
    this.pickerYearValue += direction
    const periodTypeEl = document.getElementById('period-type-filter')
    if (periodTypeEl?.value === 'month') {
      this.renderMonthPicker()
    } else {
      this.renderYearPicker()
    }
  }

  renderMonthPicker() {
    const yearDisplayEl = document.getElementById('picker-year-display')
    const gridEl = document.getElementById('picker-months-grid')
    if (!yearDisplayEl || !gridEl) return

    yearDisplayEl.textContent = this.pickerYearValue + '年'

    const periodValueEl = document.getElementById('period-value-filter')
    const currentValue = periodValueEl?.value || ''

    let html = ''
    for (let month = 1; month <= 12; month++) {
      const monthStr = String(month).padStart(2, '0')
      const value = `${this.pickerYearValue}-${monthStr}`
      const isSelected = currentValue === value
      const btnClass = isSelected
        ? 'bg-blue-500 text-white font-medium'
        : 'hover:bg-surface-hover dark:hover:bg-surface-dark-hover'
      html += `<button type="button" data-action="click->account-page#selectPickerMonth" data-account-page-month-param="${monthStr}" class="px-2 py-1.5 rounded text-xs ${btnClass}">${month}月</button>`
    }
    gridEl.innerHTML = html
  }

  renderYearPicker() {
    const yearDisplayEl = document.getElementById('picker-year-display')
    const gridEl = document.getElementById('picker-months-grid')
    if (!yearDisplayEl || !gridEl) return

    yearDisplayEl.textContent = (this.pickerYearValue - 4) + '-' + (this.pickerYearValue + 4) + '年'

    const periodValueEl = document.getElementById('period-value-filter')
    const currentYear = parseInt(periodValueEl?.value) || new Date().getFullYear()

    let html = ''
    for (let offset = -4; offset <= 4; offset++) {
      const year = this.pickerYearValue + offset
      const isSelected = year === currentYear
      const btnClass = isSelected
        ? 'bg-blue-500 text-white font-medium'
        : 'hover:bg-surface-hover dark:hover:bg-surface-dark-hover'
      html += `<button type="button" data-action="click->account-page#selectPickerYear" data-account-page-year-param="${year}" class="px-2 py-1.5 rounded text-xs ${btnClass}">${year}年</button>`
    }
    gridEl.innerHTML = html
  }

  selectPickerMonth(event) {
    const month = event.params?.month || event.currentTarget.dataset.month
    const periodValueEl = document.getElementById('period-value-filter')
    if (periodValueEl) {
      periodValueEl.value = `${this.pickerYearValue}-${month}`
    }
    this.updatePeriodValueDisplay()
    this.closePeriodPicker()
    this.applyFilters()
  }

  selectPickerYear(event) {
    const year = event.params?.year || event.currentTarget.dataset.year
    const periodValueEl = document.getElementById('period-value-filter')
    if (periodValueEl) {
      periodValueEl.value = year
    }
    this.updatePeriodValueDisplay()
    this.closePeriodPicker()
    this.applyFilters()
  }
}