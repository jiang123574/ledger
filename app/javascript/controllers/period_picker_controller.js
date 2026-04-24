import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel", "display", "yearDisplay", "grid", "prevBtn", "nextBtn",
    "periodType", "periodValue", "customDateRange", "navWrapper"
  ]

  static values = {
    pickerYear: Number,
    panelOpen: { type: Boolean, default: false }
  }

  connect() {
    this.pickerYearValue = this.currentPickerYear()
    this.updateDisplay()
    this._boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this)
    document.addEventListener('click', this._boundCloseOnOutsideClick)
  }

  disconnect() {
    document.removeEventListener('click', this._boundCloseOnOutsideClick)
  }

  currentPickerYear() {
    const type = this.periodTypeTarget?.value || 'month'
    const value = this.periodValueTarget?.value || ''
    if (type === 'month') {
      const match = value.match(/^(\d{4})/)
      return match ? parseInt(match[1]) : new Date().getFullYear()
    } else if (type === 'year') {
      return parseInt(value) || new Date().getFullYear()
    }
    return new Date().getFullYear()
  }

  toggle() {
    if (this.panelOpenValue) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    const type = this.periodTypeTarget?.value || 'month'
    this.pickerYearValue = this.currentPickerYear()

    if (type === 'month') {
      this.renderMonthPicker()
    } else if (type === 'year') {
      this.renderYearPicker()
    }

    this.panelTarget.classList.remove('hidden')
    this.panelOpenValue = true
  }

  close() {
    this.panelTarget.classList.add('hidden')
    this.panelOpenValue = false
  }

  closeOnOutsideClick(e) {
    if (this.panelOpenValue && 
        this.hasPanelTarget && 
        this.hasDisplayTarget &&
        !this.panelTarget.contains(e.target) && 
        !this.displayTarget.contains(e.target)) {
      this.close()
    }
  }

  shiftPickerYear(event) {
    const direction = parseInt(event.currentTarget.dataset.direction) || 0
    this.pickerYearValue += direction

    const type = this.periodTypeTarget?.value || 'month'
    if (type === 'month') {
      this.renderMonthPicker()
    } else if (type === 'year') {
      this.renderYearPicker()
    }
  }

  shiftPeriod(event) {
    const direction = parseInt(event.currentTarget.dataset.direction) || 0
    const type = this.periodTypeTarget?.value || 'month'
    const value = this.periodValueTarget?.value || ''

    if (type === 'year') {
      const year = parseInt(value, 10)
      if (year && year >= 2000 && year <= 2100) {
        const newYear = year + direction
        if (newYear >= 2000 && newYear <= 2100) {
          this.periodValueTarget.value = String(newYear)
          this.updateDisplay()
          this.dispatchChange()
        }
      }
    } else if (type === 'month') {
      const match = value.match(/^(\d{4})-(\d{2})$/)
      if (match) {
        let year = parseInt(match[1], 10)
        let month = parseInt(match[2], 10) + direction
        if (month < 1) {
          month = 12
          year -= 1
        } else if (month > 12) {
          month = 1
          year += 1
        }
        this.periodValueTarget.value = `${year}-${String(month).padStart(2, '0')}`
        this.updateDisplay()
        this.dispatchChange()
      }
    }
  }

  renderMonthPicker() {
    if (!this.hasYearDisplayTarget || !this.hasGridTarget) return

    this.yearDisplayTarget.textContent = this.pickerYearValue + '年'

    let currentMonth = ''
    const value = this.periodValueTarget?.value || ''
    const match = value.match(/^(\d{4})-(\d{2})$/)
    if (match && parseInt(match[1]) === this.pickerYearValue) {
      currentMonth = match[2]
    }

    const months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']
    this.gridTarget.innerHTML = months.map((m, i) => {
      const monthNum = String(i + 1).padStart(2, '0')
      const isSelected = currentMonth === monthNum
      return `<button type="button" 
        data-action="click->period-picker#selectMonth" 
        data-month="${monthNum}"
        class="px-2 py-1.5 text-xs rounded transition-smooth ${isSelected ? 'bg-blue-500 text-white' : 'hover:bg-surface-hover dark:hover:bg-surface-dark-hover text-primary dark:text-primary-dark'}">${m}</button>`
    }).join('')
  }

  renderYearPicker() {
    if (!this.hasYearDisplayTarget || !this.hasGridTarget) return

    this.yearDisplayTarget.textContent = '选择年份'

    const currentYear = parseInt(this.periodValueTarget?.value) || new Date().getFullYear()
    const startYear = this.pickerYearValue - 4
    const years = []
    for (let i = 0; i < 9; i++) {
      years.push(startYear + i)
    }

    this.gridTarget.innerHTML = years.map(y => {
      const isSelected = y === currentYear
      return `<button type="button" 
        data-action="click->period-picker#selectYear" 
        data-year="${y}"
        class="px-2 py-1.5 text-xs rounded transition-smooth ${isSelected ? 'bg-blue-500 text-white' : 'hover:bg-surface-hover dark:hover:bg-surface-dark-hover text-primary dark:text-primary-dark'}">${y}</button>`
    }).join('')
  }

  selectMonth(event) {
    const month = event.currentTarget.dataset.month
    this.periodValueTarget.value = `${this.pickerYearValue}-${month}`
    this.updateDisplay()
    this.close()
    this.dispatchChange()
  }

  selectYear(event) {
    const year = event.currentTarget.dataset.year
    this.periodValueTarget.value = year
    this.updateDisplay()
    this.close()
    this.dispatchChange()
  }

  updateDisplay() {
    if (!this.hasDisplayTarget || !this.hasPeriodTypeTarget || !this.hasPeriodValueTarget) return

    const type = this.periodTypeTarget.value
    const value = this.periodValueTarget.value

    if (type === 'year') {
      this.displayTarget.textContent = value + '年'
    } else if (type === 'month') {
      const match = value.match(/^(\d{4})-(\d{2})$/)
      if (match) {
        this.displayTarget.textContent = match[1] + '年' + parseInt(match[2]) + '月'
      }
    }
  }

  onPeriodTypeChange() {
    const type = this.periodTypeTarget.value

    if (this.hasNavWrapperTarget) {
      this.navWrapperTarget.style.display = type === 'custom' ? 'none' : ''
    }

    if (this.hasCustomDateRangeTarget) {
      this.customDateRangeTarget.classList.toggle('hidden', type !== 'custom')
      this.customDateRangeTarget.classList.toggle('flex', type === 'custom')
    }

    if (type !== 'custom') {
      const today = new Date()
      if (type === 'month') {
        const currentValue = this.periodValueTarget.value
        const yearMatch = currentValue.match(/^(\d{4})/)
        const year = yearMatch ? parseInt(yearMatch[1]) : today.getFullYear()
        this.periodValueTarget.value = `${year}-${String(today.getMonth() + 1).padStart(2, '0')}`
      } else if (type === 'year') {
        const currentValue = this.periodValueTarget.value
        const yearMatch = currentValue.match(/^(\d{4})/)
        this.periodValueTarget.value = yearMatch ? yearMatch[1] : String(today.getFullYear())
      }
      this.updateDisplay()
      this.dispatchChange()
    }
  }

  dispatchChange() {
    this.dispatch('change', { detail: { 
      type: this.periodTypeTarget?.value,
      value: this.periodValueTarget?.value 
    }})
  }
}