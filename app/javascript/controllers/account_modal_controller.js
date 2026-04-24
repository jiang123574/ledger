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
    this.typeInputTarget?.addEventListener('change', this.toggleCreditCardFields.bind(this))
  }

  openNew() {
    this.resetForm()
    this.titleTarget.textContent = '新建账户'
    this.modalTarget.classList.remove('hidden')
  }

  openEdit(event) {
    event.stopPropagation()
    const btn = event.currentTarget
    const id = btn.dataset.id
    const name = btn.dataset.name
    const type = btn.dataset.type
    const initialBalance = btn.dataset.initialBalance
    const includeInTotal = btn.dataset.includeInTotal
    const hidden = btn.dataset.hidden

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

    this.nameInputTarget.value = name
    this.typeInputTarget.value = type
    this.initialBalanceInput.value = initialBalance
    this.includeInTotalCheckboxTarget.checked = includeInTotal == '1'
    this.hiddenCheckboxTarget.checked = hidden == '1'

    this.creditLimitInputTarget.value = btn.dataset.creditLimit || ''
    this.billingDayInputTarget.value = btn.dataset.billingDay || ''
    this.billingDayModeInputTarget.value = btn.dataset.billingDayMode || ''
    this.dueDayModeInputTarget.value = btn.dataset.dueDayMode || ''
    this.dueDayInputTarget.value = btn.dataset.dueDay || ''
    this.dueDayOffsetInputTarget.value = btn.dataset.dueDayOffset || ''

    this.toggleCreditCardFields()

    this.deleteBtnContainerTarget.innerHTML = `<button type="button" data-action="click->account-modal#confirmDelete" data-id="${id}" data-name="${name}" class="px-4 py-1.5 text-sm font-medium rounded-lg border border-red-300 text-red-600 dark:border-red-700 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-smooth">删除账户</button>`

    this.modalTarget.classList.remove('hidden')
  }

  close() {
    this.modalTarget.classList.add('hidden')
    this.resetForm()
  }

  resetForm() {
    this.titleTarget.textContent = '新建账户'
    this.formTarget.action = '/accounts'
    this.formTarget.method = 'post'

    if (this.hasMethodInputTarget) {
      this.methodInputTarget.remove()
    }

    this.nameInputTarget.value = ''
    this.typeInputTarget.value = ''
    this.initialBalanceInputTarget.value = ''
    this.includeInTotalCheckboxTarget.checked = true
    this.hiddenCheckboxTarget.checked = false
    this.deleteBtnContainerTarget.innerHTML = ''

    this.creditLimitInputTarget.value = ''
    this.billingDayInputTarget.value = ''
    this.billingDayModeInputTarget.value = ''
    this.dueDayModeInputTarget.value = ''
    this.dueDayInputTarget.value = ''
    this.dueDayOffsetInputTarget.value = ''

    this.toggleCreditCardFields()
  }

  toggleCreditCardFields() {
    const type = this.typeInputTarget?.value
    if (type === 'CREDIT') {
      this.creditCardFieldsTarget.classList.remove('hidden')
    } else {
      this.creditCardFieldsTarget.classList.add('hidden')
    }
  }

  confirmDelete(event) {
    const btn = event.currentTarget
    const id = btn.dataset.id
    const name = btn.dataset.name

    if (!window.confirm(`确定要删除账户 "${name}" 吗？\n\n若该账户仍有关联交易/应收/应付记录，将无法删除。`)) return

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
  }
}