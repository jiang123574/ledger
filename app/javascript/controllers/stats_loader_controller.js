import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["balance", "income", "expense", "net"]
  static values = {
    accountId: String,
    periodType: String,
    periodValue: String,
    type: String
  }

  connect() {
    this.loadStats()
  }

  loadStats() {
    const params = new URLSearchParams()
    if (this.accountIdValue) params.append('account_id', this.accountIdValue)
    params.append('period_type', this.periodTypeValue || 'month')
    if (this.periodTypeValue !== 'all') {
      params.append('period_value', this.periodValueValue || this.getDefaultPeriodValue())
    }
    if (this.typeValue) params.append('type', this.typeValue)
    // include selected category filters if present on page
    if (window.selectedCategoryIds && Array.isArray(window.selectedCategoryIds) && window.selectedCategoryIds.length > 0) {
      window.selectedCategoryIds.forEach(id => params.append('category_ids[]', id));
    }

    fetch(`/accounts/stats?${params}`)
      .then(response => response.json())
      .then(data => {
        this.updateDisplay(data)
      })
      .catch(error => {
        console.error('Failed to load stats:', error)
      })
  }

  updateDisplay(data) {
    if (this.hasBalanceTarget) {
      this.balanceTarget.textContent = this.formatCurrency(data.account_balance)
    }
    
    if (this.hasIncomeTarget) {
      this.incomeTarget.textContent = this.formatCurrency(data.total_income)
    }
    
    if (this.hasExpenseTarget) {
      this.expenseTarget.textContent = this.formatCurrency(data.total_expense)
    }
    
    if (this.hasNetTarget) {
      this.netTarget.textContent = this.formatCurrency(data.total_balance)
      this.netTarget.classList.remove('text-income', 'text-expense')
      this.netTarget.classList.add(data.total_balance >= 0 ? 'text-income' : 'text-expense')
    }
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat('zh-CN', {
      style: 'currency',
      currency: 'CNY'
    }).format(amount || 0)
  }

  getDefaultPeriodValue() {
    const periodType = this.periodTypeValue || 'month'
    switch (periodType) {
      case 'year':
        return new Date().getFullYear().toString()
      case 'week':
        const date = new Date()
        const week = this.getISOWeek(date)
        return `${date.getFullYear()}-W${week.toString().padStart(2, '0')}`
      default:
        return new Date().toISOString().slice(0, 7)
    }
  }

  getISOWeek(date) {
    const target = new Date(date.valueOf())
    const dayNr = (date.getDay() + 6) % 7
    target.setDate(target.getDate() - dayNr + 3)
    const jan4 = new Date(target.getFullYear(), 0, 4)
    const dayDiff = (target - jan4) / 86400000
    return 1 + Math.ceil(dayDiff / 7)
  }
}