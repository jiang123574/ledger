import { Controller } from "@hotwired/stimulus"

// 账单管理 Stimulus controller
// 替换 accounts/index.html.erb 中的全局 window 函数
export default class extends Controller {
  static targets = [
    "cards", "countBtn", "filterBtn",
    "periodInfo", "dueInfo",
    "detailSection", "defaultHint",
    "statementModal", "billingDate", "statementAmount"
  ]

  static values = {
    accountId: String
  }

  connect() {
    this.currentBillCount = 3
    this.selectedBillLabel = null
    this.selectedStartDate = null
    this.selectedEndDate = null
    this.allBillEntries = []
    this.currentBillFilter = "all"

    // 供外部调用的全局引用（局部刷新后需要）
    window.loadBillsWithCount = this.loadBillsWithCount.bind(this)
    window.showStatementInputModal = this.showStatementInputModal.bind(this)
    window.hideStatementInputModal = this.hideStatementInputModal.bind(this)
    window.saveStatementAmount = this.saveStatementAmount.bind(this)
    window.selectBill = this.selectBill.bind(this)
    window.filterBillEntries = this.filterBillEntries.bind(this)
    window.initCreditBills = this.init.bind(this)

    if (this.accountIdValue) {
      this.init()
    }
  }

  disconnect() {
    // 清理全局引用
    delete window.loadBillsWithCount
    delete window.showStatementInputModal
    delete window.hideStatementInputModal
    delete window.saveStatementAmount
    delete window.selectBill
    delete window.filterBillEntries
    delete window.initCreditBills
  }

  init() {
    const wrapper = document.getElementById("credit-bill-wrapper")
    const accountId = this.accountIdValue || wrapper?.dataset?.accountId
    if (!accountId) return

    this.accountIdValue = accountId
    this.loadBillsWithCount(this.currentBillCount)
  }

  // === 账单卡片加载 ===

  loadBillsWithCount(count) {
    this.currentBillCount = count

    // 更新计数按钮样式
    this.countBtnTargets.forEach(btn => {
      btn.classList.remove("bg-blue-50", "dark:bg-blue-900/30", "text-blue-600", "dark:text-blue-400")
      btn.classList.add("hover:bg-surface-hover", "dark:hover:bg-surface-dark-hover")
      if (btn.dataset.count == count) {
        btn.classList.add("bg-blue-50", "dark:bg-blue-900/30", "text-blue-600", "dark:text-blue-400")
        btn.classList.remove("hover:bg-surface-hover", "dark:hover:bg-surface-dark-hover")
      }
    })

    fetch(`/accounts/${this.accountIdValue}/bills.json?count=${count}`)
      .then(r => r.json())
      .then(data => this.renderBillCards(data))
      .catch(err => console.error("Failed to load bills:", err))
  }

  renderBillCards(data) {
    const container = this.hasCardsTarget ? this.cardsTarget : document.getElementById("bill-cards")
    if (!container) return

    if (!data.bills || data.bills.length === 0) {
      container.innerHTML = '<div class="text-sm text-secondary dark:text-secondary-dark">暂无账单数据</div>'
      return
    }

    let html = ""
    data.bills.forEach(bill => {
      const isUnbilled = bill.unbilled
      const isSelected = this.selectedBillLabel === bill.label
      let cardClass = "shrink-0 p-3 rounded-lg cursor-pointer transition-smooth min-w-[180px] "

      if (isSelected) {
        cardClass += "bg-blue-100 dark:bg-blue-900/40 ring-2 ring-blue-400"
      } else if (isUnbilled) {
        cardClass += "bg-orange-50 dark:bg-orange-900/20 border border-orange-200 dark:border-orange-800 hover:border-orange-400"
      } else {
        cardClass += "bg-gray-50 dark:bg-surface-dark border border-transparent hover:border-border dark:hover:border-border-dark"
      }

      html += `<div class="${cardClass}" data-action="click->bill-statement#handleCardClick" data-label="${this.escapeHtml(bill.label)}" data-start-date="${bill.start_date}" data-end-date="${bill.end_date}">`

      // 卡片标题
      html += '<div class="flex items-center justify-between mb-2">'
      if (isUnbilled) {
        html += '<span class="font-semibold text-sm text-orange-600 dark:text-orange-400">未出账单</span>'
        html += '<span class="text-[10px] px-1.5 py-0.5 rounded bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400">进行中</span>'
      } else {
        html += `<span class="font-semibold text-sm text-primary dark:text-primary-dark">${bill.label}</span>`
        const displayAmount = bill.statement_amount || bill.balance_due || 0
        html += `<span class="font-bold text-expense ml-2">${this.formatBillMoney(displayAmount)}</span>`
      }
      html += "</div>"

      // 消费金额和还款退款并排显示
      html += '<div class="flex justify-between text-xs mb-2">'
      html += `<div><span class="text-secondary dark:text-secondary-dark">消费：</span><span class="font-medium">${this.formatBillMoney(bill.spend_amount || 0)}</span></div>`
      html += `<div class="text-right"><span class="text-secondary dark:text-secondary-dark">还款退款：</span><span class="font-medium text-income">${this.formatBillMoney(bill.repay_amount || 0)}</span></div>`
      html += "</div>"

      // 账期范围
      html += '<div class="text-xs text-secondary dark:text-secondary-dark mb-1.5">'
      html += `账期：${bill.start_date} ~ ${bill.end_date}`
      html += "</div>"

      // 账单日 & 还款日
      html += '<div class="text-xs text-secondary dark:text-secondary-dark mb-2">'
      html += `账单日：${bill.end_date}  还款日：${bill.due_date}`
      html += "</div>"

      // 笔数
      html += '<div class="flex justify-between text-xs pt-1.5 border-t border-border/50 dark:border-border-dark/50">'
      html += `<div><span class="text-secondary dark:text-secondary-dark">消费笔数：</span><span class="font-medium tabular-nums">${bill.spend_count || 0}笔</span></div>`
      html += `<div class="text-right"><span class="text-secondary dark:text-secondary-dark">还款笔数：</span><span class="font-medium tabular-nums">${bill.repay_count || 0}笔</span></div>`
      html += "</div></div>"
    })

    container.innerHTML = html

    // 渲染完成后确保详情区状态与选中卡片一致
    const targetBill = data.bills.find(b => b.label === this.selectedBillLabel) || data.bills[0]
    if (targetBill) {
      this.selectBill(targetBill.label, targetBill.start_date, targetBill.end_date)
    }
  }

  // === 账单卡片点击（事件委托） ===

  handleCardClick(event) {
    const card = event.currentTarget
    this.selectBill(card.dataset.label, card.dataset.startDate, card.dataset.endDate)
  }

  // === 账单选择 ===

  selectBill(label, startDate, endDate) {
    this.selectedBillLabel = label
    this.selectedStartDate = startDate
    this.selectedEndDate = endDate

    // 更新卡片选中状态
    const container = this.hasCardsTarget ? this.cardsTarget : document.getElementById("bill-cards")
    if (container) {
      container.querySelectorAll(":scope > div").forEach(card => {
        const isCardSelected = card.dataset.label === label
        card.className = card.className
          .replace(/ring-\w+-\d+/g, "").trim()
          .replace(/bg-blue-100 dark:bg-blue-900\/40/g, "")
          .replace(/ring-2 ring-blue-400/g, "")
        if (isCardSelected) {
          card.className += " bg-blue-100 dark:bg-blue-900/40 ring-2 ring-blue-400"
        }
      })
    }

    // 更新账期信息栏
    if (this.hasPeriodInfoTarget) this.periodInfoTarget.textContent = `账期：${startDate} ~ ${endDate}`
    if (this.hasDueInfoTarget) this.dueInfoTarget.textContent = ""

    // 加载交易明细
    this.loadBillEntries()

    // 显示详情区
    const detailSection = document.getElementById("bill-detail-section")
    const defaultHint = document.getElementById("bill-default-hint")
    if (detailSection) detailSection.classList.remove("hidden")
    if (defaultHint) defaultHint.classList.add("hidden")
  }

  // === 账单明细加载 ===

  loadBillEntries() {
    if (!this.accountIdValue || !this.selectedStartDate || !this.selectedEndDate) return

    // 通知 credit-bill-entries controller 显示 loading
    this.dispatchBillEntriesEvent("credit-bill-entries:loading")

    fetch(`/accounts/${this.accountIdValue}/bills_entries.json?start_date=${this.selectedStartDate}&end_date=${this.selectedEndDate}`, {
      headers: { "X-Requested-With": "XMLHttpRequest" }
    })
      .then(r => r.json())
      .then(data => {
        this.allBillEntries = data.entries || []
        this.applyFilter()
      })
      .catch(err => {
        console.error(err)
        this.dispatchBillEntriesEvent("credit-bill-entries:error", { message: "加载失败" })
      })
  }

  // === 筛选 ===

  filterBillEntries(filter) {
    this.currentBillFilter = filter

    // 更新按钮样式
    this.filterBtnTargets.forEach(btn => {
      if (btn.dataset.filter === filter) {
        btn.className = "bill-filter-btn px-2 py-0.5 rounded bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400"
      } else {
        btn.className = "bill-filter-btn px-2 py-0.5 rounded hover:bg-surface-hover text-primary dark:text-primary-dark"
      }
    })

    this.applyFilter()
  }

  applyFilter() {
    const filtered = this.allBillEntries.filter(e => {
      if (this.currentBillFilter === "all") return true
      if (this.currentBillFilter === "repay") return e.is_repayment
      if (this.currentBillFilter === "spend") return e.is_spend
      return true
    })
    this.dispatchBillEntriesEvent("credit-bill-entries:render", { entries: filtered })
  }

  // === 录入基准账单弹窗 ===

  showStatementInputModal() {
    const modal = document.getElementById("statement-input-modal")
    if (modal) modal.classList.remove("hidden")
  }

  hideStatementInputModal() {
    const modal = document.getElementById("statement-input-modal")
    if (modal) modal.classList.add("hidden")
  }

  saveStatementAmount() {
    const billingDateEl = document.getElementById("statement-billing-date")
    const amountEl = document.getElementById("statement-amount")
    const billingDate = billingDateEl?.value
    const amount = amountEl?.value

    if (!billingDate || !amount) {
      alert("请填写账单日期和金额")
      return
    }

    fetch(`/accounts/${this.accountIdValue}/create_bill_statement`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify({ billing_date: billingDate, statement_amount: amount })
    })
      .then(r => r.json())
      .then(data => {
        if (data.success) {
          this.hideStatementInputModal()
          this.loadBillsWithCount(this.currentBillCount)
        } else {
          alert(data.error || "保存失败")
        }
      })
  }

  // === 工具方法 ===

  dispatchBillEntriesEvent(eventName, detail = {}) {
    const container = document.getElementById("bill-detail-section")
    if (!container) return false
    container.dispatchEvent(new CustomEvent(eventName, { detail, bubbles: true }))
    return true
  }

  escapeHtml(str) {
    if (!str) return ""
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;")
  }

  formatBillMoney(amount) {
    const num = parseFloat(amount) || 0
    return num.toLocaleString("zh-CN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }
}
