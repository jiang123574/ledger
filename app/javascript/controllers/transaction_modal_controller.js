import { Controller } from "@hotwired/stimulus"
import { initSelectorWithData } from "selectors"
import { createEntryCard } from "entry_card_renderer"

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

    // 暴露全局函数供快捷键使用
    window.openNewTransactionModal = this.openNewTransactionModal.bind(this)
    window.toggleTransferMode = this.toggleTransferMode.bind(this)
    window.transactionMode = this.transactionMode

    this.initNewModalSelectors()
    this.initFundingAccountSelector()
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

      // 只有在 type 不是 TRANSFER 时才同步
      // 防止在转账模式下错误清空源账户值
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

    // 显示删除确认弹窗
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

    // 恢复删除按钮状态
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
          this.removeEntryFromList(id)
          this.showSuccessToast(data.message || '交易已删除')

          // 更新分类明细弹窗的合计（使用全局存储的活跃controller）
          if (window.activeCategoryDetailController && typeof window.activeCategoryDetailController.updateTotalAfterDelete === 'function') {
            window.activeCategoryDetailController.updateTotalAfterDelete(id)
          }
        } else {
          this.showErrorToast(data.error || '删除失败')
          if (deleteBtn) {
            deleteBtn.textContent = originalText
            deleteBtn.disabled = false
          }
        }
      })
      .catch(() => {
        this.showErrorToast('网络错误，请重试')
        if (deleteBtn) {
          deleteBtn.textContent = originalText
          deleteBtn.disabled = false
        }
      })
  }

  removeEntryFromList(id) {
    // 同时处理多个容器（按日期 + 按账单 + 分类明细弹窗）
    const containers = [
      document.querySelector('#transactions-container'),
      document.querySelector('#bill-entries-container'),
      document.querySelector('[data-detail-container]')
    ].filter(c => c)

    containers.forEach(container => {
      // 收集要删除的元素
      const elementsToRemove = []

      // 桌面端行
      const desktopRow = container.querySelector(`[data-entry-id="${id}"]`)
      if (desktopRow) elementsToRemove.push(desktopRow)

      // 移动端卡片
      const mobileRow = container.querySelector(`[data-mobile-entry-id="${id}"]`)
      if (mobileRow) elementsToRemove.push(mobileRow)

      // 添加动画类
      elementsToRemove.forEach(el => {
        el.style.transition = 'opacity 0.2s, height 0.3s, padding 0.3s, margin 0.3s'
        el.style.opacity = '0'
        el.style.height = '0'
        el.style.padding = '0'
        el.style.margin = '0'
        el.style.overflow = 'hidden'
      })

      // 动画结束后移除元素
      setTimeout(() => {
        elementsToRemove.forEach(el => el.remove())
      }, 300)
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

    this.initCategorySelector()
    this.initAccountSelector()
  }

  initCategorySelector() {
    initSelectorWithData({
      searchInputId: 'category-search-input',
      dropdownId: 'category-dropdown',
      optionsId: 'category-options',
      hiddenInputId: 'new_transaction_category_id',
      dataSource: this.allCategories,  // 显示所有分类
      noMatchText: '无匹配分类',
      enableLevelIndent: true,
      onSelect: (value, item) => {
        if (item && item.type) {
          this.currentType = item.type;
          const typeInput = document.getElementById('transaction-type-input');
          if (typeInput) typeInput.value = item.type;
          // funding-account-field 只在支出时显示
          const fundingField = document.getElementById('funding-account-field');
          if (fundingField) {
            fundingField.classList.toggle('hidden', item.type !== 'EXPENSE');
          }
        }
      }
    });
  }

  initAccountSelector() {
    initSelectorWithData({
      searchInputId: 'account-search-input-income',
      dropdownId: 'account-dropdown-income',
      optionsId: 'account-options-income',
      hiddenInputId: 'transaction_account_id_income',
      dataSource: this.allAccounts,
      noMatchText: '无匹配账户'
    })
  }

  initTransferSelectors() {
    initSelectorWithData({
      searchInputId: 'account-search-input',
      dropdownId: 'account-dropdown',
      optionsId: 'account-options',
      hiddenInputId: 'transaction_account_id',
      dataSource: this.allAccounts,
      noMatchText: '无匹配账户'
    })

    initSelectorWithData({
      searchInputId: 'target-account-search-input',
      dropdownId: 'target-account-dropdown',
      optionsId: 'target-account-options',
      hiddenInputId: 'target_account_id',
      dataSource: this.allAccounts,
      noMatchText: '无匹配账户'
    })
  }

  initFundingAccountSelector() {
    initSelectorWithData({
      searchInputId: 'funding-account-search-input',
      dropdownId: 'funding-account-dropdown',
      optionsId: 'funding-account-options',
      hiddenInputId: 'funding_account_id',
      dataSource: this.allAccounts,
      noMatchText: '无匹配账户',
      emptyOption: { label: '不补记资金来源', value: '', display: '' }
    })
  }

  getFilteredCategories() {
    return this.allCategories  // 显示所有分类，不再过滤
  }

  toggleTransferMode() {
    if (this.transactionMode === 'category') {
      this.transactionMode = 'transfer'
      window.transactionMode = 'transfer'
      this.showTransferFields()
      this.hideCategoryFields()
      // 清空收支模式的账户值，防止混淆
      const incomeHidden = document.getElementById('transaction_account_id_income')
      if (incomeHidden) incomeHidden.value = ''
      const incomeSearch = document.getElementById('account-search-input-income')
      if (incomeSearch) incomeSearch.value = ''
      // 强制重新初始化转账选择器
      this.forceInitTransferSelectors()
      const typeInput = document.getElementById('transaction-type-input')
      if (typeInput) typeInput.value = 'TRANSFER'
    } else {
      this.transactionMode = 'category'
      window.transactionMode = 'category'
      this.hideTransferFields()
      this.showCategoryFields()
      // 清空转账账户值
      const sourceHidden = document.getElementById('transaction_account_id')
      if (sourceHidden) sourceHidden.value = ''
      const targetHidden = document.getElementById('target_account_id')
      if (targetHidden) targetHidden.value = ''
      this.initCategorySelector()
      this.initAccountSelector()
      const typeInput = document.getElementById('transaction-type-input')
      if (typeInput) typeInput.value = this.currentType
    }
  }

  // 强制重新初始化转账选择器（绕过 selectorBound 检查）
  forceInitTransferSelectors() {
    const sourceSearch = document.getElementById('account-search-input')
    const targetSearch = document.getElementById('target-account-search-input')
    if (sourceSearch) sourceSearch.dataset.selectorBound = 'false'
    if (targetSearch) targetSearch.dataset.selectorBound = 'false'
    this.initTransferSelectors()
  }

  showTransferFields() {
    document.getElementById('target-account-field')?.classList.remove('hidden')
    document.getElementById('account-field-wrapper')?.classList.add('hidden')
    // 转账模式下隐藏实际资金来源字段（此功能只在支出模式下有效）
    document.getElementById('funding-account-field')?.classList.add('hidden')
  }

  hideTransferFields() {
    document.getElementById('target-account-field')?.classList.add('hidden')
  }

  showCategoryFields() {
    document.getElementById('category-field-wrapper')?.classList.remove('hidden')
    document.getElementById('account-field-wrapper')?.classList.remove('hidden')
    // 根据当前类型决定是否显示实际资金来源字段
    const fundingField = document.getElementById('funding-account-field')
    if (fundingField) {
      fundingField.classList.toggle('hidden', this.currentType !== 'EXPENSE')
    }
  }

  hideCategoryFields() {
    document.getElementById('category-field-wrapper')?.classList.add('hidden')
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
    if (!amountInput?.value || parseFloat(amountInput.value) <= 0) {
      this.showErrorToast('请输入有效金额')
      return
    }

    const sourceHidden = document.getElementById('transaction_account_id')
    const incomeHidden = document.getElementById('transaction_account_id_income')
    const typeInput = document.getElementById('transaction-type-input')
    const actualType = typeInput?.value || 'EXPENSE'

    // 只有在 type 不是 TRANSFER 时才同步
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
          this.showSuccessToast(data.message || '交易已创建，请继续录入')
          const amountInput = form.querySelector('input[name="transaction[amount]"]')
          const noteInput = form.querySelector('input[name="transaction[note]"]')
          if (amountInput) amountInput.value = ''
          if (noteInput) noteInput.value = ''

          // 检查当前视图模式
          const urlParams = new URLSearchParams(window.location.search)
          const viewMode = urlParams.get('view_mode')

          if (viewMode === 'bill') {
            // 按账单模式：检查日期范围后插入到账单明细列表
            const billController = this.getBillStatementController()
            if (billController && data.entry) {
              const entryDate = data.entry.date
              const startDate = billController.selectedStartDate
              const endDate = billController.selectedEndDate
              
              if (entryDate >= startDate && entryDate <= endDate) {
                this.insertEntryToBillContainer(data.entry)
              } else {
                this.showInfoToast('交易已创建，不在当前账单期')
              }
            } else if (data.entries && data.entries.length > 0) {
              // 多条交易（带资金来源转账场景）
              data.entries.forEach(entry => {
                const entryDate = entry.date
                const startDate = billController?.selectedStartDate
                const endDate = billController?.selectedEndDate
                
                if (billController && entryDate >= startDate && entryDate <= endDate) {
                  this.insertEntryToBillContainer(entry)
                } else {
                  this.showInfoToast('交易已创建，不在当前账单期')
                }
              })
            }
          } else {
            // 按日期模式：插入到列表顶部
            if (data.entry) {
              this.insertEntryToList(data.entry)
            } else if (data.entries && data.entries.length > 0) {
              this.insertEntriesToList(data.entries)
            }
          }
        } else {
          this.showErrorToast(data.error || '保存失败')
        }
      })
      .catch(error => {
        console.error('Submit error:', error)
        this.showErrorToast('网络错误，请重试')
      })
      .finally(() => {
        continueBtn.textContent = originalText
        continueBtn.disabled = false
      })
  }

  showSuccessToast(message) {
    const toast = document.createElement('div')
    toast.className = 'fixed top-4 right-4 bg-green-500 text-white px-4 py-2 rounded-lg shadow-lg z-50'
    toast.textContent = message
    document.body.appendChild(toast)
    setTimeout(() => {
      toast.style.opacity = '0'
      toast.style.transition = 'opacity 0.3s'
      setTimeout(() => toast.remove(), 300)
    }, 2000)
  }

  showErrorToast(message) {
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

  insertEntryToList(entry) {
    const container = document.querySelector('#transactions-container')
    if (!container || !entry) return

    const cardFragment = createEntryCard(entry, {
      onEdit: (id) => window.openEditTransactionModal?.({ params: { id } }),
      onDelete: this.getDeleteCallback()
    })

    container.insertBefore(cardFragment, container.firstChild)

    this.addHighlightAnimation(container, entry.id)
  }

  addHighlightAnimation(container, entryId) {
    const desktopRow = container.querySelector(`[data-entry-id="${entryId}"]`)
    const mobileRow = container.querySelector(`[data-mobile-entry-id="${entryId}"]`)
    if (desktopRow) {
      desktopRow.classList.add('bg-blue-50', 'dark:bg-blue-900/20')
      setTimeout(() => {
        desktopRow.classList.remove('bg-blue-50', 'dark:bg-blue-900/20')
      }, 2000)
    }
    if (mobileRow) {
      mobileRow.classList.add('bg-blue-50', 'dark:bg-blue-900/20')
      setTimeout(() => {
        mobileRow.classList.remove('bg-blue-50', 'dark:bg-blue-900/20')
      }, 2000)
    }
  }

  getDeleteCallback() {
    return (id, name) => {
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
          this.removeEntryFromList(id)
          this.showSuccessToast(data.message || '交易已删除')
        } else {
          this.showErrorToast(data.error || '删除失败')
        }
      })
      .catch(() => {
        this.showErrorToast('网络错误，请重试')
      })
  }

  // 插入多条 entry 到列表顶部（用于带资金来源转账场景）
  insertEntriesToList(entries) {
    if (!entries || entries.length === 0) return

    // 按顺序插入（第一条在最上面，后面的依次排在下面）
    entries.forEach(entry => {
      this.insertEntryToList(entry)
    })
  }

  // 插入 entry 到账单明细容器（用于按账单模式）
  insertEntryToBillContainer(entry) {
    const container = document.querySelector('#bill-entries-container')
    if (!container || !entry) return

    const cardFragment = createEntryCard(entry, {
      onEdit: (id) => window.openEditTransactionModal?.({ params: { id } }),
      onDelete: this.getDeleteCallback()
    })

    container.insertBefore(cardFragment, container.firstChild)

    this.addHighlightAnimation(container, entry.id)
  }

  // 获取 bill-statement controller 实例
  getBillStatementController() {
    const element = document.querySelector('[data-controller="bill-statement"]')
    if (element && window.Stimulus) {
      return window.Stimulus.getControllerForElementAndIdentifier(element, 'bill-statement')
    }
    return null
  }

  // 显示信息提示（用于非成功/错误的提示）
  showInfoToast(message) {
    const toast = document.createElement('div')
    toast.className = 'fixed top-4 right-4 bg-blue-500 text-white px-4 py-2 rounded-lg shadow-lg z-50'
    toast.textContent = message
    document.body.appendChild(toast)
    setTimeout(() => {
      toast.style.opacity = '0'
      toast.style.transition = 'opacity 0.3'
      setTimeout(() => toast.remove(), 300)
    }, 2500)
  }
}