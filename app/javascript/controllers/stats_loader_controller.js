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
    console.log('StatsLoader connected')
    console.log('accountId:', this.accountIdValue)
    console.log('periodType:', this.periodTypeValue)
    console.log('hasBalanceTarget:', this.hasBalanceTarget)
    console.log('hasIncomeTarget:', this.hasIncomeTarget)
    console.log('hasExpenseTarget:', this.hasExpenseTarget)
    console.log('hasNetTarget:', this.hasNetTarget)
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

    console.log('Fetching stats:', `/accounts/stats?${params}`)
    
    fetch(`/accounts/stats?${params}`)
      .then(response => {
        console.log('Response status:', response.status)
        return response.json()
      })
      .then(data => {
        console.log('Stats data:', data)
        this.updateDisplay(data)
      })
      .catch(error => {
        console.error('Failed to load stats:', error)
      })
  }

  updateDisplay(data) {
    console.log('Updating display with data:', data)
    
    if (this.hasBalanceTarget) {
      const formattedBalance = this.formatCurrency(data.account_balance)
      console.log('Setting balance:', formattedBalance)
      this.balanceTarget.textContent = formattedBalance
    } else {
      console.warn('No balance target found')
    }
    
    if (this.hasIncomeTarget) {
      const formattedIncome = this.formatCurrency(data.total_income)
      console.log('Setting income:', formattedIncome)
      this.incomeTarget.textContent = formattedIncome
    } else {
      console.warn('No income target found')
    }
    
    if (this.hasExpenseTarget) {
      const formattedExpense = this.formatCurrency(data.total_expense)
      console.log('Setting expense:', formattedExpense)
      this.expenseTarget.textContent = formattedExpense
    } else {
      console.warn('No expense target found')
    }
    
    if (this.hasNetTarget) {
      const formattedNet = this.formatCurrency(data.total_balance)
      console.log('Setting net:', formattedNet)
      this.netTarget.textContent = formattedNet
      this.netTarget.classList.remove('text-income', 'text-expense')
      this.netTarget.classList.add(data.total_balance >= 0 ? 'text-income' : 'text-expense')
    } else {
      console.warn('No net target found')
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