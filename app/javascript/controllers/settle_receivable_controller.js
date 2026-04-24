import { Controller } from "@hotwired/stimulus"
import { initSelectorWithData } from "selectors"

export default class extends Controller {
  static targets = [
    "amountInput", "receivableIdInput", "accountIdInput",
    "dateInput", "noteInput", "submitBtn"
  ]

  connect() {
    this.allAccounts = this.loadDataSource('accounts-data', [])
    this.allReceivables = this.loadDataSource('receivables-data', [])

    // 暴露全局函数供快捷键调用
    window.openSettleReceivableModal = this.open.bind(this)
  }

  disconnect() {
    window.openSettleReceivableModal = undefined
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
    const form = document.getElementById('settle-receivable-form')
    if (form) form.reset()

    const dateInput = document.getElementById('settle-date')
    if (dateInput) dateInput.value = new Date().toISOString().split('T')[0]

    const receivableIdInput = document.getElementById('settle-receivable-id')
    if (receivableIdInput) receivableIdInput.value = ''

    const accountIdInput = document.getElementById('settle-account-id')
    if (accountIdInput) accountIdInput.value = ''
  }

  initSelectors() {
    // 应收款选择器
    initSelectorWithData({
      searchInputId: 'settle-receivable-search',
      dropdownId: 'settle-receivable-dropdown',
      filterInputId: 'settle-receivable-filter',
      optionsId: 'settle-receivable-options',
      hiddenInputId: 'settle-receivable-id',
      dataSource: this.allReceivables,
      noMatchText: '无匹配应收款'
    })

    // 账户选择器
    initSelectorWithData({
      searchInputId: 'settle-account-search',
      dropdownId: 'settle-account-dropdown',
      filterInputId: 'settle-account-filter',
      optionsId: 'settle-account-options',
      hiddenInputId: 'settle-account-id',
      dataSource: this.allAccounts,
      noMatchText: '无匹配账户'
    })

    // 监听应收款选择变化，自动填充金额
    const receivableIdInput = document.getElementById('settle-receivable-id')
    if (receivableIdInput) {
      receivableIdInput.addEventListener('change', () => this.setFullAmount())
    }
  }

  setFullAmount() {
    const receivableId = document.getElementById('settle-receivable-id')?.value
    if (!receivableId) return

    const receivable = this.allReceivables.find(r => r.id == receivableId)
    if (receivable) {
      const amountInput = document.getElementById('settle-amount')
      if (amountInput) amountInput.value = receivable.remaining_amount
    }
  }

  submit(event) {
    event.preventDefault()

    const receivableId = document.getElementById('settle-receivable-id')?.value
    const amount = document.getElementById('settle-amount')?.value
    const accountId = document.getElementById('settle-account-id')?.value
    const settlementDate = document.getElementById('settle-date')?.value
    const noteInput = document.querySelector('#settle-receivable-form input[name="note"]')
    const note = noteInput?.value || ''

    if (!receivableId || !amount || !accountId || !settlementDate) {
      this.showError('请填写必填字段')
      return
    }

    const submitBtn = document.querySelector('#settle-receivable-form button[type="submit"]')
    const originalText = submitBtn?.textContent || '提交'
    if (submitBtn) {
      submitBtn.disabled = true
      submitBtn.textContent = '提交中...'
    }

    fetch(`/receivables/${receivableId}/settle`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        amount: amount,
        account_id: accountId,
        settlement_date: settlementDate,
        note: note
      })
    })
      .then(response => {
        if (response.ok || response.redirected) {
          window.location.reload()
        } else {
          return response.json().then(data => {
            throw new Error(data.error || '报销失败')
          })
        }
      })
      .catch(error => {
        console.error('Error:', error)
        this.showError(error.message || '报销失败，请重试')
        if (submitBtn) {
          submitBtn.disabled = false
          submitBtn.textContent = originalText
        }
      })
  }

  showError(message) {
    const toast = document.createElement('div')
    toast.className = 'fixed top-4 right-4 bg-red-500 text-white px-4 py-2 rounded-lg shadow-lg z-50'
    toast.textContent = message
    document.body.appendChild(toast)
    setTimeout(() => {
      toast.style.opacity = '0'
      toast.style.transition = 'opacity 0.3s'
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }
}