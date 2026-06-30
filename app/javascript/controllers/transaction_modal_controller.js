import { Controller } from "@hotwired/stimulus"
import { showSuccessToast, showErrorToast, showInfoToast } from "utils/toast_utils"
import { insertEntryToList, insertEntriesToList, insertEntryToBillContainer, removeEntryFromList, getBillStatementController } from "utils/entry_list_utils"
import { createCategorySelector, createIncomeAccountSelector, createTransferSelectors, createFundingAccountSelector, forceInitTransferSelectors } from "utils/selector_factory"

export default class extends Controller {
  static targets = [
    "newModal", "editModal", "editContent",
    "categoryFieldWrapper", "categoryField", "categoryHidden",
    "categorySearchInput", "categoryDropdown", "categoryFilterInput", "categoryOptions",
    "accountFieldWrapper", "accountHidden", "accountSearchInput",
    "accountDropdown", "accountFilterInput", "accountOptions",
    "transferField", "transferSourceHidden", "transferSourceSearchInput",
    "transferSourceDropdown", "transferSourceFilterInput", "transferSourceOptions",
    "transferTargetHidden", "transferTargetSearchInput",
    "transferTargetDropdown", "transferTargetFilterInput", "transferTargetOptions",
    "fundingAccountField", "fundingAccountHidden", "fundingAccountSearchInput",
    "fundingAccountDropdown", "fundingAccountFilterInput", "fundingAccountOptions",
    "typeHiddenInput", "amountInput", "dateInput", "noteInput"
  ]

  static values = {
    mode: { type: String, default: 'expense' },
    accountId: String
  }

  connect() {
    this.transactionMode = 'category'
    this.currentType = 'EXPENSE'

    this.allAccounts = this.loadDataSource('accounts-data', [])
    this.allCategories = this.loadDataSource('all-categories-data', [])

    // Expose global functions for shortcuts
    window.openNewTransactionModal = this.openNewTransactionModal.bind(this)
    window.toggleTransferMode = this.toggleTransferMode.bind(this)
    window.transactionMode = this.transactionMode

    this.initNewModalSelectors()
    createFundingAccountSelector({ dataSource: this.allAccounts })
    this.setupFormSubmitSync()
  }

  setupFormSubmitSync() {
    const form = document.querySelector('#add-transaction-modal form')
    if (!form) return

    form.addEventListener('submit', (e) => {
      const sourceHidden = document.getElementById('transaction_account_id')
      const incomeHidden = document.getElementById('transaction_account_id_income')
      const typeInput = document.getElementById('transaction-type-input')
      const actualType = typeInput?.value || 'EXPENSE'

      // Only sync when type is not TRANSFER
      if (actualType !== 'TRANSFER') {
        if (incomeHidden && sourceHidden) {
          sourceHidden.value = incomeHidden.value
        }
      }
    })
  }

  disconnect() {
    window.openNewTransactionModal = undefined
    window.toggleTransferMode = undefined
    window.transactionMode = undefined
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

  openNewTransactionModal() {
    const modal = document.getElementById('add-transaction-modal')
    if (modal) {
      modal.classList.remove('hidden')
      this.resetToCategoryMode()
      this.setDefaultAccount()
      const amountInput = document.querySelector('#add-transaction-modal input[name="transaction[amount]"]')
      if (amountInput) amountInput.value = ''

      const swapBtn = document.getElementById('swap-account-funding-btn')
      if (swapBtn) swapBtn.classList.toggle('hidden', this.currentType !== 'EXPENSE')
    }
  }

  openEditTransactionModal(event) {
    const id = event.params?.id || event.currentTarget.dataset.id
    const container = document.getElementById('edit-transaction-content')
    if (container) container.innerHTML = ''

    fetch(`/transactions/${id}/edit`, {
      headers: { 'Accept': 'text/html', 'X-Requested-With': 'XMLHttpRequest' }
    })
      .then(res => res.text())
      .then(html => {
        if (container) {
          container.innerHTML = html
          this.executeScripts(container)
        }
        const modal = document.getElementById('edit-transaction-modal')
        if (modal) modal.classList.remove('hidden')
      })
      .catch(err => console.error('Error loading transaction:', err))
  }

  executeScripts(container) {
    container.querySelectorAll('script').forEach(script => {
      const newScript = document.createElement('script')
      if (script.src) newScript.src = script.src
      else newScript.textContent = script.textContent
      document.body.appendChild(newScript)
      document.body.removeChild(newScript)
    })
  }

  confirmDeleteTransaction(event) {
    const id = event.params?.id || event.currentTarget.dataset.id
    const name = event.params?.name || event.currentTarget.dataset.name || '这笔交易'

    const modal = document.getElementById('delete-confirm-modal')
    const nameEl = document.getElementById('delete-entry-name')
    const idEl = document.getElementById('delete-entry-id')

    if (modal && nameEl && idEl) {
      nameEl.textContent = name
      idEl.value = id
      modal.classList.remove('hidden')
    }
  }

  closeDeleteModal() {
    const modal = document.getElementById('delete-confirm-modal')
    if (modal) modal.classList.add('hidden')

    const deleteBtn = modal?.querySelector('button[data-action="click->transaction-modal#executeDelete"]')
    if (deleteBtn) {
      deleteBtn.textContent = '删除'
      deleteBtn.disabled = false
    }
  }

  executeDelete() {
    const idEl = document.getElementById('delete-entry-id')
    const id = idEl?.value
    if (!id) return

    const deleteBtn = document.querySelector('#delete-confirm-modal button[data-action="click->transaction-modal#executeDelete"]')
    const originalText = deleteBtn?.textContent
    if (deleteBtn) {
      deleteBtn.textContent = '删除中...'
      deleteBtn.disabled = true
    }

    fetch(`/transactions/${id}.json`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          this.closeDeleteModal()
          removeEntryFromList(id)
          showSuccessToast(data.message || '交易已删除')

          // Update category detail modal total
          if (window.activeCategoryDetailController && typeof window.activeCategoryDetailController.updateTotalAfterDelete === 'function') {
            window.activeCategoryDetailController.updateTotalAfterDelete(id)
          }
        } else {
          showErrorToast(data.error || '删除失败')
          if (deleteBtn) {
            deleteBtn.textContent = originalText
            deleteBtn.disabled = false
          }
        }
      })
      .catch(() => {
        showErrorToast('网络错误，请重试')
        if (deleteBtn) {
          deleteBtn.textContent = originalText
          deleteBtn.disabled = false
        }
      })
  }

  initNewModalSelectors() {
    if (this.allAccounts.length === 0) {
      const accountsEl = document.getElementById('accounts-data')
      if (accountsEl) this.allAccounts = JSON.parse(accountsEl.textContent || '[]')
    }
    if (this.allCategories.length === 0) {
      const categoriesEl = document.getElementById('all-categories-data')
      if (categoriesEl) this.allCategories = JSON.parse(categoriesEl.textContent || '[]')
    }

    createCategorySelector({
      dataSource: this.allCategories,
      onSelect: (type, item) => {
        this.currentType = type
        const typeInput = document.getElementById('transaction-type-input')
        if (typeInput) typeInput.value = type

        const fundingField = document.getElementById('funding-account-field')
        if (fundingField) {
          fundingField.classList.toggle('hidden', type !== 'EXPENSE')
        }
        const swapBtn = document.getElementById('swap-account-funding-btn')
        if (swapBtn) swapBtn.classList.toggle('hidden', type !== 'EXPENSE')
      }
    })

    createIncomeAccountSelector({ dataSource: this.allAccounts })
  }

  toggleTransferMode() {
    if (this.transactionMode === 'category') {
      // 先获取当前设置的账户（用于转账时设为转出账户）
      const incomeHidden = document.getElementById('transaction_account_id_income')
      const incomeSearch = document.getElementById('account-search-input-income')
      const currentAccountId = incomeHidden?.value || ''
      const currentAccountName = incomeSearch?.value || ''

      this.transactionMode = 'transfer'
      window.transactionMode = 'transfer'
      this.showTransferFields()
      this.hideCategoryFields()

      // Clear income account values
      if (incomeHidden) incomeHidden.value = ''
      if (incomeSearch) incomeSearch.value = ''

      forceInitTransferSelectors(this.allAccounts)

      // 将之前设置的账户设为转出账户
      if (currentAccountId) {
        const sourceHidden = document.getElementById('transaction_account_id')
        const sourceSearch = document.getElementById('account-search-input')
        if (sourceHidden) sourceHidden.value = currentAccountId
        if (sourceSearch) sourceSearch.value = currentAccountName
      }

      const typeInput = document.getElementById('transaction-type-input')
      if (typeInput) typeInput.value = 'TRANSFER'
    } else {
      this.transactionMode = 'category'
      window.transactionMode = 'category'
      this.hideTransferFields()
      this.showCategoryFields()

      // Clear transfer account values
      const sourceHidden = document.getElementById('transaction_account_id')
      if (sourceHidden) sourceHidden.value = ''
      const targetHidden = document.getElementById('target_account_id')
      if (targetHidden) targetHidden.value = ''

      createCategorySelector({
        dataSource: this.allCategories,
        onSelect: (type) => {
          this.currentType = type
          const typeInput = document.getElementById('transaction-type-input')
          if (typeInput) typeInput.value = type
        }
      })
      createIncomeAccountSelector({ dataSource: this.allAccounts })

      const typeInput = document.getElementById('transaction-type-input')
      if (typeInput) typeInput.value = this.currentType
    }
  }

  showTransferFields() {
    document.getElementById('target-account-field')?.classList.remove('hidden')
    document.getElementById('account-field-wrapper')?.classList.add('hidden')
    document.getElementById('funding-account-field')?.classList.add('hidden')
    const btn = document.getElementById('full-transfer-btn')
    if (btn) btn.style.display = ''
  }

  hideTransferFields() {
    document.getElementById('target-account-field')?.classList.add('hidden')
    const btn = document.getElementById('full-transfer-btn')
    if (btn) btn.style.display = 'none'
  }

  showCategoryFields() {
    document.getElementById('category-field-wrapper')?.classList.remove('hidden')
    document.getElementById('account-field-wrapper')?.classList.remove('hidden')
    const btn = document.getElementById('full-transfer-btn')
    if (btn) btn.style.display = 'none'

    const fundingField = document.getElementById('funding-account-field')
    if (fundingField) {
      fundingField.classList.toggle('hidden', this.currentType !== 'EXPENSE')
    }
    const swapBtn = document.getElementById('swap-account-funding-btn')
    if (swapBtn) swapBtn.classList.toggle('hidden', this.currentType !== 'EXPENSE')
  }

  hideCategoryFields() {
    document.getElementById('category-field-wrapper')?.classList.add('hidden')
    document.getElementById('swap-account-funding-btn')?.classList.add('hidden')
  }

  resetToCategoryMode() {
    if (this.transactionMode === 'transfer') {
      this.toggleTransferMode()
    }
  }

  swapTransferAccounts() {
    const sourceHidden = document.getElementById('transaction_account_id')
    const targetHidden = document.getElementById('target_account_id')
    const sourceInput = document.getElementById('account-search-input')
    const targetInput = document.getElementById('target-account-search-input')

    if (!sourceHidden || !targetHidden) return

    const tmpId = sourceHidden.value
    const tmpName = sourceInput?.value || ''
    sourceHidden.value = targetHidden.value
    if (sourceInput) sourceInput.value = targetInput?.value || ''
    targetHidden.value = tmpId
    if (targetInput) targetInput.value = tmpName
  }

  swapAccountAndFunding() {
    const accountHidden = document.getElementById('transaction_account_id_income')
    const accountInput = document.getElementById('account-search-input-income')
    const fundingHidden = document.getElementById('funding_account_id')
    const fundingInput = document.getElementById('funding-account-search-input')

    if (!accountHidden || !fundingHidden) return

    const tmpId = accountHidden.value
    const tmpName = accountInput?.value || ''
    accountHidden.value = fundingHidden.value
    if (accountInput) accountInput.value = fundingInput?.value || ''
    fundingHidden.value = tmpId
    if (fundingInput) fundingInput.value = tmpName
  }

  setFullTransferAmount() {
    const sourceHidden = document.getElementById('transaction_account_id')
    if (!sourceHidden?.value) return

    const account = this.allAccounts.find(a => a.id == sourceHidden.value)
    if (!account?.balance) return

    const amountInput = document.querySelector('#add-transaction-modal input[name="transaction[amount]"]')
    if (amountInput) amountInput.value = account.balance
  }

  setDefaultAccount() {
    const urlParams = new URLSearchParams(window.location.search)
    const accountId = urlParams.get('account_id')
    if (!accountId) return

    const account = this.allAccounts.find(a => a.id == accountId)
    if (account) {
      const hiddenInput = document.getElementById('transaction_account_id_income')
      const searchInput = document.getElementById('account-search-input-income')
      if (hiddenInput) hiddenInput.value = account.id
      if (searchInput) searchInput.value = account.name
    }
  }

  closeNewModal() {
    document.getElementById('add-transaction-modal')?.classList.add('hidden')
  }

  closeEditModal() {
    document.getElementById('edit-transaction-modal')?.classList.add('hidden')
  }

  submitAndContinue(event) {
    event.preventDefault()

    const form = document.querySelector('#add-transaction-modal form')
    if (!form) return

    const amountInput = form.querySelector('input[name="transaction[amount]"]')
    const amount = parseFloat(amountInput.value)
    if (!amountInput?.value || isNaN(amount)) {
      showErrorToast('请输入有效金额')
      return
    }

    const sourceHidden = document.getElementById('transaction_account_id')
    const incomeHidden = document.getElementById('transaction_account_id_income')
    const typeInput = document.getElementById('transaction-type-input')
    const actualType = typeInput?.value || 'EXPENSE'

    if (actualType !== 'TRANSFER') {
      if (incomeHidden && sourceHidden) {
        sourceHidden.value = incomeHidden.value
      }
    }

    const formData = new FormData(form)
    formData.append('continue_entry', '1')

    const continueBtn = event.target
    const originalText = continueBtn.textContent
    continueBtn.textContent = '保存中...'
    continueBtn.disabled = true

    fetch(form.action.replace(/\/$/, '') + '.json', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: formData
    })
      .then(response => {
        if (!response.ok) {
          return response.text().then(text => {
            try { return JSON.parse(text) }
            catch(e) { return { success: false, error: '服务器错误' } }
          })
        }
        return response.json()
      })
      .then(data => {
        if (data.success) {
          showSuccessToast(data.message || '交易已创建，请继续录入')
          const amountInput = form.querySelector('input[name="transaction[amount]"]')
          const noteInput = form.querySelector('input[name="transaction[note]"]')
          if (amountInput) amountInput.value = ''
          if (noteInput) noteInput.value = ''

          const urlParams = new URLSearchParams(window.location.search)
          const viewMode = urlParams.get('view_mode')

          if (viewMode === 'bill') {
            const billController = getBillStatementController()
            if (billController && data.entry) {
              const entryDate = data.entry.date
              const startDate = billController.selectedStartDate
              const endDate = billController.selectedEndDate

              if (entryDate >= startDate && entryDate <= endDate) {
                insertEntryToBillContainer(data.entry, this.getEntryOptions())
              } else {
                showInfoToast('交易已创建，不在当前账单期')
              }
            } else if (data.entries && data.entries.length > 0) {
              data.entries.forEach(entry => {
                const entryDate = entry.date
                const startDate = billController?.selectedStartDate
                const endDate = billController?.selectedEndDate

                if (billController && entryDate >= startDate && entryDate <= endDate) {
                  insertEntryToBillContainer(entry, this.getEntryOptions())
                } else {
                  showInfoToast('交易已创建，不在当前账单期')
                }
              })
            }
          } else {
            if (data.entry) {
              insertEntryToList(data.entry, this.getEntryOptions())
            } else if (data.entries && data.entries.length > 0) {
              insertEntriesToList(data.entries, this.getEntryOptions())
            }
          }
        } else {
          showErrorToast(data.error || '保存失败')
        }
      })
      .catch(error => {
        console.error('Submit error:', error)
        showErrorToast('网络错误，请重试')
      })
      .finally(() => {
        continueBtn.textContent = originalText
        continueBtn.disabled = false
      })
  }

  getEntryOptions() {
    return {
      onEdit: (id) => window.openEditTransactionModal?.({ params: { id } }),
      onDelete: (id, name) => {
        window.showConfirmDialog?.({
          title: "确认删除",
          content: `确定删除 <strong>${name}</strong> 吗？此操作不可撤销。`,
          confirmText: "删除",
          cancelText: "取消",
          danger: true
        }).then(confirmed => {
          if (confirmed) this.executeDeleteRequest(id)
        })
      }
    }
  }

  executeDeleteRequest(id) {
    fetch(`/transactions/${id}.json`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          removeEntryFromList(id)
          showSuccessToast(data.message || '交易已删除')
        } else {
          showErrorToast(data.error || '删除失败')
        }
      })
      .catch(() => {
        showErrorToast('网络错误，请重试')
      })
  }
}