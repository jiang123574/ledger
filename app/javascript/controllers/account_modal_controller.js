import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", "title", "form", "nameInput", "typeInput", "initialBalanceInput",
    "includeInTotalCheckbox", "hiddenCheckbox", "creditCardFields",
    "creditLimitInput", "billingDayInput", "billingDayModeInput",
    "dueDayModeInput", "dueDayInput", "dueDayOffsetInput",
    "deleteBtnContainer", "methodInput"
  ]

  static values = {
    accountId: String,
    accountName: String
  }

  connect() {
    if (this.hasTypeInputTarget) {
      this.typeInputTarget.addEventListener('change', this.toggleCreditCardFields.bind(this))
    }
    // 暴露全局函数供快捷键和按钮使用
    window.openNewAccountModal = this.openNew.bind(this)
    window.openEditAccountModal = this.openEdit.bind(this)
  }

  disconnect() {
    window.openNewAccountModal = undefined
    window.openEditAccountModal = undefined
  }

  openNew() {
    this.resetForm()
    this.titleTarget.textContent = '新建账户'
    this.modalTarget.classList.remove('hidden')
  }

  openEdit(btn) {
    // 支持两种调用方式：event 或 button 元素
    if (btn?.currentTarget) btn = btn.currentTarget
    if (!btn?.dataset) {
      console.error('openEdit called with invalid argument:', btn)
      return
    }
    if (btn.stopPropagation) btn.stopPropagation()

    const id = btn.dataset.id
    const name = btn.dataset.name
    const type = btn.dataset.type
    const initialBalance = btn.dataset.initialBalance
    const includeInTotal = btn.dataset.includeInTotal
    const hidden = btn.dataset.hidden

    if (!this.hasModalTarget || !this.hasTitleTarget || !this.hasFormTarget) {
      console.error('account-modal controller targets not found')
      return
    }

    this.titleTarget.textContent = '编辑账户'
    this.formTarget.action = '/accounts/' + id
    this.formTarget.method = 'post'

    if (!this.hasMethodInputTarget) {
      const methodInput = document.createElement('input')
      methodInput.type = 'hidden'
      methodInput.name = '_method'
      methodInput.value = 'patch'
      methodInput.dataset.accountModalTarget = 'methodInput'
      this.formTarget.appendChild(methodInput)
    } else {
      this.methodInputTarget.value = 'patch'
    }

    if (this.hasNameInputTarget) this.nameInputTarget.value = name
    if (this.hasTypeInputTarget) this.typeInputTarget.value = type
    if (this.hasInitialBalanceInputTarget) this.initialBalanceInputTarget.value = initialBalance
    if (this.hasIncludeInTotalCheckboxTarget) this.includeInTotalCheckboxTarget.checked = includeInTotal == '1'
    if (this.hasHiddenCheckboxTarget) this.hiddenCheckboxTarget.checked = hidden == '1'

    if (this.hasCreditLimitInputTarget) this.creditLimitInputTarget.value = btn.dataset.creditLimit || ''
    if (this.hasBillingDayInputTarget) this.billingDayInputTarget.value = btn.dataset.billingDay || ''
    if (this.hasBillingDayModeInputTarget) this.billingDayModeInputTarget.value = btn.dataset.billingDayMode || ''
    if (this.hasDueDayModeInputTarget) this.dueDayModeInputTarget.value = btn.dataset.dueDayMode || ''
    if (this.hasDueDayInputTarget) this.dueDayInputTarget.value = btn.dataset.dueDay || ''
    if (this.hasDueDayOffsetInputTarget) this.dueDayOffsetInputTarget.value = btn.dataset.dueDayOffset || ''

    this.toggleCreditCardFields()

    if (this.hasDeleteBtnContainerTarget) {
      this.deleteBtnContainerTarget.innerHTML = `<button type="button" data-action="click->account-modal#confirmDelete" data-id="${id}" data-name="${name}" class="px-4 py-1.5 text-sm font-medium rounded-lg border border-red-300 text-red-600 dark:border-red-700 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-smooth">删除账户</button>`
    }

    this.modalTarget.classList.remove('hidden')
  }

  close() {
    this.modalTarget.classList.add('hidden')
    this.resetForm()
  }

  resetForm() {
    if (this.hasTitleTarget) this.titleTarget.textContent = '新建账户'
    if (this.hasFormTarget) {
      this.formTarget.action = '/accounts'
      this.formTarget.method = 'post'
    }

    if (this.hasMethodInputTarget) {
      this.methodInputTarget.remove()
    }

    if (this.hasNameInputTarget) this.nameInputTarget.value = ''
    if (this.hasTypeInputTarget) this.typeInputTarget.value = ''
    if (this.hasInitialBalanceInputTarget) this.initialBalanceInputTarget.value = ''
    if (this.hasIncludeInTotalCheckboxTarget) this.includeInTotalCheckboxTarget.checked = true
    if (this.hasHiddenCheckboxTarget) this.hiddenCheckboxTarget.checked = false
    if (this.hasDeleteBtnContainerTarget) this.deleteBtnContainerTarget.innerHTML = ''

    if (this.hasCreditLimitInputTarget) this.creditLimitInputTarget.value = ''
    if (this.hasBillingDayInputTarget) this.billingDayInputTarget.value = ''
    if (this.hasBillingDayModeInputTarget) this.billingDayModeInputTarget.value = ''
    if (this.hasDueDayModeInputTarget) this.dueDayModeInputTarget.value = ''
    if (this.hasDueDayInputTarget) this.dueDayInputTarget.value = ''
    if (this.hasDueDayOffsetInputTarget) this.dueDayOffsetInputTarget.value = ''

    this.toggleCreditCardFields()
  }

  toggleCreditCardFields() {
    const type = this.hasTypeInputTarget ? this.typeInputTarget.value : ''
    if (this.hasCreditCardFieldsTarget) {
      if (type === 'CREDIT') {
        this.creditCardFieldsTarget.classList.remove('hidden')
      } else {
        this.creditCardFieldsTarget.classList.add('hidden')
      }
    }
  }

  confirmDelete(event) {
    const btn = event.currentTarget
    const id = btn.dataset.id
    const name = btn.dataset.name

    // 使用通用确认弹窗替代浏览器原生 confirm
    window.showConfirmDialog({
      title: "确认删除",
      content: `确定要删除账户 <strong>"${name}"</strong> 吗？<br><br><span class="text-sm">若该账户仍有关联交易/应收/应付记录，将无法删除。</span>`,
      confirmText: "删除",
      cancelText: "取消",
      danger: true
    }).then(confirmed => {
      if (!confirmed) return

      const form = document.createElement('form')
      form.method = 'POST'
      form.action = '/accounts/' + id

      const methodInput = document.createElement('input')
      methodInput.type = 'hidden'
      methodInput.name = '_method'
      methodInput.value = 'delete'
      form.appendChild(methodInput)

      const token = document.querySelector('meta[name="csrf-token"]')?.content
      if (token) {
        const csrfInput = document.createElement('input')
        csrfInput.type = 'hidden'
        csrfInput.name = 'authenticity_token'
        csrfInput.value = token
        form.appendChild(csrfInput)
      }

      document.body.appendChild(form)
      form.submit()
    })
  }
}