import { Controller } from "@hotwired/stimulus"
import { formatMoney, formatCurrencyRaw } from "bill_formatters"

// 分类明细展示控制器
// 点击分类行后，弹窗展示该分类在该时间段的所有交易记录

export default class extends Controller {
  static values = {
    startDate: String,
    endDate: String,
    modalSelector: { type: String, default: "#category-detail-modal" }
  }

  connect() {
    // ESC 键关闭
    this.handleEsc = (e) => {
      if (e.key === "Escape") {
        const modal = this.getModal()
        if (modal && !modal.classList.contains("hidden")) {
          this.close()
        }
      }
    }
    document.addEventListener("keydown", this.handleEsc)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleEsc)
  }

  getModal() {
    return document.querySelector(this.modalSelectorValue)
  }

  // 点击分类行，显示明细
  async show(event) {
    const row = event.currentTarget
    const categoryId = row.dataset.categoryId
    const categoryName = row.querySelector(".text-sm.font-medium")?.textContent || "分类明细"

    if (!categoryId) return

    const modal = this.getModal()
    if (!modal) {
      console.error("Modal not found:", this.modalSelectorValue)
      return
    }

    const container = modal.querySelector('[data-detail-container]')
    const titleEl = modal.querySelector('[data-detail-title]')
    const totalEl = modal.querySelector('[data-detail-total]')

    // 显示弹窗和加载状态
    modal.classList.remove("hidden")
    if (titleEl) titleEl.textContent = categoryName

    if (container) {
      container.innerHTML = `<div class="p-4 text-center text-secondary dark:text-secondary-dark text-sm">加载中...</div>`
    }

    // 绑定关闭事件
    this.bindCloseEvents(modal)

    try {
      const params = new URLSearchParams()
      params.set("category_ids[]", categoryId)
      params.set("start_date", this.startDateValue)
      params.set("end_date", this.endDateValue)
      params.set("per_page", "100")
      params.set("format", "json")

      const response = await fetch(`/accounts/entries?${params.toString()}`, {
        headers: { "X-Requested-With": "XMLHttpRequest" }
      })

      if (!response.ok) {
        throw new Error("加载失败")
      }

      const data = await response.json()
      const entries = data.entries || []

      // 显示总数
      const totalAmount = entries.reduce((sum, e) => {
        const amount = e.display_amount_type === "INCOME" ? e.display_amount : -e.display_amount
        return sum + amount
      }, 0)
      if (totalEl) {
        totalEl.textContent = `${entries.length} 笔交易，合计 ¥${Math.abs(totalAmount).toFixed(2)}`
      }

      // 渲染交易列表
      if (container) {
        this.renderEntries(container, entries)
      }

    } catch (error) {
      console.error("加载分类明细失败:", error)
      if (container) {
        container.innerHTML = `<div class="p-4 text-center text-red-500 text-sm">加载失败，请重试</div>`
      }
    }
  }

  // 渲染交易列表（表格形式）
  renderEntries(container, entries) {
    if (!entries || entries.length === 0) {
      container.innerHTML = `<div class="p-8 text-center text-secondary dark:text-secondary-dark text-sm">该分类暂无交易记录</div>`
      return
    }

    const transactionModalController = this.getTransactionModalController()
    const typeBadgeClass = (displayType) => {
      const classes = {
        "收入": "bg-income-light text-income",
        "转入": "bg-income-light text-income",
        "支出": "bg-expense-light text-expense",
        "转出": "bg-expense-light text-expense",
        "转账": "bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300"
      }
      return classes[displayType] || "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300"
    }

    container.innerHTML = entries.map(entry => {
      const isTransfer = entry.display_type === "转账" || entry.display_type === "转入" || entry.display_type === "转出"
      const isIncome = entry.display_amount_type === "INCOME"
      const amountText = formatMoney(Math.abs(entry.display_amount || 0))
      const typeBadgeCls = typeBadgeClass(entry.display_type)

      // 流入流出
      let inflowHtml = ""
      let outflowHtml = ""
      if (isTransfer && entry.show_both_amounts) {
        inflowHtml = `<span class="text-income">+${amountText}</span>`
        outflowHtml = `<span class="text-expense">-${amountText}</span>`
      } else if (isIncome) {
        inflowHtml = `<span class="text-income">+${amountText}</span>`
      } else {
        outflowHtml = `<span class="text-expense">-${amountText}</span>`
      }

      // 备注：只显示用户填写的备注
      const noteHtml = entry.note ? `<span class="truncate">${entry.note}</span>` : ""

      // 账户
      const accountHtml = isTransfer && entry.transfer_from && entry.transfer_to
        ? `${entry.transfer_from} → ${entry.transfer_to}`
        : entry.account_name || "未知账户"

      return `
        <div class="hidden lg:flex items-center py-1.5 px-4 border-b border-border/50 dark:border-border-dark/50 hover:bg-surface-hover dark:hover:bg-surface-dark-hover transition-smooth" data-entry-id="${entry.id}">
          <div class="shrink-0 text-xs text-secondary dark:text-secondary-dark truncate pr-2" style="width: 80px;">${entry.date || ""}</div>
          <div class="shrink-0 truncate flex items-center gap-2 pr-2" style="width: 150px;">
            <span class="shrink-0 inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${typeBadgeCls}">${entry.display_type || ""}</span>
            <span class="text-sm font-medium text-primary dark:text-primary-dark truncate">${entry.display_name || "-"}</span>
          </div>
          <div class="shrink-0 text-right text-sm font-medium truncate pr-3" style="width: 80px;">${inflowHtml}</div>
          <div class="shrink-0 text-right text-sm font-medium truncate pr-4" style="width: 80px;">${outflowHtml}</div>
          <div class="flex-1 min-w-0 text-xs text-secondary dark:text-secondary-dark truncate pl-1">${noteHtml}</div>
          <div class="shrink-0 flex items-center justify-center gap-1.5" style="width: 70px;">
            <button type="button" data-action="edit" data-entry-id="${entry.id}" class="p-1 rounded hover:bg-surface dark:hover:bg-surface-dark text-secondary dark:text-secondary-dark hover:text-primary transition-smooth">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
            </button>
            <button type="button" data-action="delete" data-entry-id="${entry.id}" data-entry-name="${entry.display_name || ''}" class="p-1 rounded hover:bg-expense-light text-secondary dark:text-secondary-dark hover:text-expense transition-smooth">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
            </button>
          </div>
        </div>
        <!-- 移动端 -->
        <div class="lg:hidden flex gap-2 items-center py-2 px-4 border-b border-border/50 dark:border-border-dark/50 hover:bg-surface-hover dark:hover:bg-surface-dark-hover transition-smooth" data-mobile-entry-id="${entry.id}">
          <div class="shrink-0 text-xs text-secondary dark:text-secondary-dark">${entry.date?.slice(5) || ""}</div>
          <div class="flex-1 min-w-0 flex flex-col gap-0.5">
            <div class="flex items-center gap-1.5">
              <span class="shrink-0 inline-flex items-center px-1 py-0.5 rounded text-[10px] font-medium ${typeBadgeCls}">${entry.display_type || ""}</span>
              <span class="text-sm font-medium text-primary dark:text-primary-dark truncate">${entry.display_name || "-"}</span>
            </div>
            <div class="text-xs text-secondary dark:text-secondary-dark truncate pl-4">${noteHtml}</div>
          </div>
          <div class="text-right shrink-0">
            <p class="text-sm font-medium ${isIncome ? 'text-income' : 'text-expense'}">${isIncome ? '+' : '-'}${amountText}</p>
          </div>
        </div>
      `
    }).join('')

    // 绑定编辑删除按钮事件
    container.querySelectorAll('[data-action="edit"]').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.dataset.entryId
        if (transactionModalController) {
          transactionModalController.openEditTransactionModal({ params: { id } })
        }
      })
    })

    container.querySelectorAll('[data-action="delete"]').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.dataset.entryId
        const name = btn.dataset.entryName
        if (transactionModalController) {
          transactionModalController.confirmDeleteTransaction({ params: { id, name } })
        }
      })
    })
  }

  bindCloseEvents(modal) {
    // 移除旧的事件处理器
    if (modal._detailCloseHandlers) {
      modal._detailCloseHandlers.forEach(({ el, handler, event }) => {
        el.removeEventListener(event, handler)
      })
    }

    const handlers = []

    // 关闭按钮
    const closeBtn = modal.querySelector('[data-detail-close]')
    if (closeBtn) {
      const handler = () => this.close()
      closeBtn.addEventListener("click", handler)
      handlers.push({ el: closeBtn, handler, event: "click" })
    }

    // 点击遮罩层关闭
    const overlayBg = modal.querySelector('[data-detail-overlay]')
    if (overlayBg) {
      const handler = () => this.close()
      overlayBg.addEventListener("click", handler)
      handlers.push({ el: overlayBg, handler, event: "click" })
    }

    modal._detailCloseHandlers = handlers
  }

  close() {
    const modal = this.getModal()
    if (modal) {
      modal.classList.add("hidden")
    }
  }

  getTransactionModalController() {
    const element = document.querySelector('[data-controller="transaction-modal"]')
    if (element && window.Stimulus) {
      return window.Stimulus.getControllerForElementAndIdentifier(element, 'transaction-modal')
    }
    return null
  }
}