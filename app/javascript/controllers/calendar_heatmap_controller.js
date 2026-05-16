import { Controller } from "@hotwired/stimulus"
import { formatMoney } from "bill_formatters"

// HTML转义函数，防止XSS攻击
function escapeHtml(text) {
  if (!text) return ""
  const div = document.createElement('div')
  div.textContent = text
  return div.innerHTML
}

// 全局存储当前活跃的controller实例（用于删除后更新）
window.activeHeatmapController = null

export default class extends Controller {
  static targets = ["chart"]
  static values = {
    data: Array,
    year: Number,
    modalSelector: { type: String, default: "#category-detail-modal" }
  }

  connect() {
    if (document.documentElement.hasAttribute('data-turbo-preview')) {
      return
    }
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

    this.scheduleDraw()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleEsc)
    const tooltip = document.getElementById("heatmap-tooltip")
    if (tooltip) {
      tooltip.remove()
    }
  }

  dataValueChanged() {
    if (document.documentElement.hasAttribute('data-turbo-preview')) {
      return
    }
    this.scheduleDraw()
  }

  scheduleDraw() {
    if (this._drawScheduled) return
    this._drawScheduled = true
    requestAnimationFrame(() => {
      this._drawScheduled = false
      this.draw()
    })
  }

  draw() {
    if (this._drawing) return
    this._drawing = true

    const chart = this.chartTarget
    const data = this.dataValue
    const year = this.yearValue || new Date().getFullYear()

    if (!chart || !data || !Array.isArray(data) || data.length === 0) {
      this._drawing = false
      return
    }

    chart.innerHTML = ""

    const cellSize = 12
    const padding = { top: 30, right: 10, bottom: 10, left: 40 }
    const monthLabelHeight = 20

    const months = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]
    const days = ["日", "一", "二", "三", "四", "五", "六"]

    const width = cellSize * 53 + padding.left + padding.right
    const height = cellSize * 7 + padding.top + padding.bottom + monthLabelHeight

    chart.setAttribute("viewBox", `0 0 ${width} ${height}`)
    chart.style.width = "100%"

    const isDark = document.documentElement.classList.contains("dark")
    const textColor = isDark ? "#f8f9fa" : "#1a1a1a"
    const emptyColor = isDark ? "#262626" : "#f0f0f0"

    const colors = {
      1: isDark ? "#1a3d1a" : "#c6e48b",
      2: isDark ? "#2a5c2a" : "#7bc96f",
      3: isDark ? "#3a7a3a" : "#239a3b",
      4: isDark ? "#4a994a" : "#196127",
      5: isDark ? "#5ab85a" : "#0d4420"
    }

    for (let i = 0; i < months.length; i++) {
      const text = document.createElementNS("http://www.w3.org/2000/svg", "text")
      text.setAttribute("x", padding.left + i * 4.5 * cellSize + cellSize)
      text.setAttribute("y", padding.top - 10)
      text.setAttribute("fill", textColor)
      text.setAttribute("font-size", "11")
      text.setAttribute("text-anchor", "start")
      text.textContent = months[i]
      chart.appendChild(text)
    }

    for (let i = 0; i < days.length; i++) {
      if (i % 2 === 1) continue
      const text = document.createElementNS("http://www.w3.org/2000/svg", "text")
      text.setAttribute("x", padding.left - 5)
      text.setAttribute("y", padding.top + monthLabelHeight + i * cellSize + cellSize / 2 + 4)
      text.setAttribute("fill", textColor)
      text.setAttribute("font-size", "10")
      text.setAttribute("text-anchor", "end")
      text.textContent = days[i]
      chart.appendChild(text)
    }

    const validData = data.filter(d => d && d.date)
    const dataMap = new Map(validData.map(d => [d.date, d]))

    const startDate = new Date(year, 0, 1)
    const endDate = new Date(year, 11, 31)

    let currentDate = new Date(startDate)
    while (currentDate <= endDate) {
      const dayOfWeek = currentDate.getDay()
      const weekOfYear = this.getWeekOfYear(currentDate)

      const dateStr = this.formatDate(currentDate)
      const dayData = dataMap.get(dateStr)

      const x = padding.left + weekOfYear * cellSize
      const y = padding.top + monthLabelHeight + dayOfWeek * cellSize

      const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect")
      rect.setAttribute("x", x)
      rect.setAttribute("y", y)
      rect.setAttribute("width", cellSize - 2)
      rect.setAttribute("height", cellSize - 2)
      rect.setAttribute("rx", 2)
      rect.setAttribute("ry", 2)

      if (dayData && dayData.level) {
        const levelColor = colors[dayData.level] || colors[1]
        rect.setAttribute("fill", levelColor)
        rect.setAttribute("data-date", dateStr)
        rect.setAttribute("data-amount", dayData.amount || 0)
        rect.setAttribute("data-count", dayData.count || 0)
        rect.classList.add("cursor-pointer")

        rect.addEventListener("mouseenter", (e) => {
          this.showTooltip(e, dayData)
        })
        rect.addEventListener("mouseleave", () => {
          this.hideTooltip()
        })
        rect.addEventListener("click", () => {
          this.showDayDetail(dateStr, dayData)
        })
      } else {
        rect.setAttribute("fill", emptyColor)
      }

      chart.appendChild(rect)

      currentDate.setDate(currentDate.getDate() + 1)
    }

    this._drawing = false
  }

  getWeekOfYear(date) {
    const jan1 = new Date(date.getFullYear(), 0, 1)
    const jan1DayOfWeek = jan1.getDay()
    const dayOfYear = Math.floor((date - jan1) / (24 * 60 * 60 * 1000))
    return Math.floor((dayOfYear + jan1DayOfWeek) / 7)
  }

  formatDate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")
    return `${year}-${month}-${day}`
  }

  showTooltip(event, data) {
    let tooltip = document.getElementById("heatmap-tooltip")
    if (!tooltip) {
      tooltip = document.createElement("div")
      tooltip.id = "heatmap-tooltip"
      tooltip.className = "fixed bg-container dark:bg-container-dark text-primary dark:text-primary-dark text-xs px-2 py-1 rounded shadow-lg z-50 pointer-events-none"
      document.body.appendChild(tooltip)
    }

    tooltip.textContent = `${data.date}: ¥${data.amount.toFixed(2)} (${data.count}笔)`
    tooltip.style.left = `${event.clientX + 10}px`
    tooltip.style.top = `${event.clientY - 30}px`
    tooltip.classList.remove("hidden")
  }

  hideTooltip() {
    const tooltip = document.getElementById("heatmap-tooltip")
    if (tooltip) {
      tooltip.classList.add("hidden")
    }
  }

  getModal() {
    return document.querySelector(this.modalSelectorValue)
  }

  // 点击日期方格，显示当日交易明细
  async showDayDetail(dateStr, dayData) {
    const modal = this.getModal()
    if (!modal) {
      console.error("Modal not found:", this.modalSelectorValue)
      return
    }

    const container = modal.querySelector('[data-detail-container]')
    const titleEl = modal.querySelector('[data-detail-title]')
    const totalEl = modal.querySelector('[data-detail-total]')

    // 格式化日期显示
    const dateDisplay = this.formatDateDisplay(dateStr)

    // 显示弹窗和加载状态
    modal.classList.remove("hidden")
    if (titleEl) titleEl.textContent = `${dateDisplay} 交易明细`

    // 存储当前活跃的controller实例到全局（用于删除后更新）
    window.activeHeatmapController = this

    if (container) {
      container.innerHTML = `<div class="p-4 text-center text-secondary dark:text-secondary-dark text-sm">加载中...</div>`
    }

    // 绑定关闭事件
    this.bindCloseEvents(modal)

    try {
      const params = new URLSearchParams()
      params.set("start_date", dateStr)
      params.set("end_date", dateStr)
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
        const amountValue = parseFloat(e.display_amount) || 0
        const amount = e.display_amount_type === "INCOME" ? amountValue : -amountValue
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
      console.error("加载日期明细失败:", error)
      if (container) {
        container.innerHTML = `<div class="p-4 text-center text-red-500 text-sm">加载失败，请重试</div>`
      }
    }
  }

  formatDateDisplay(dateStr) {
    const date = new Date(dateStr)
    const month = date.getMonth() + 1
    const day = date.getDate()
    return `${month}月${day}日`
  }

  // 渲染交易列表（表格形式）
  renderEntries(container, entries) {
    if (!entries || entries.length === 0) {
      container.innerHTML = `<div class="p-8 text-center text-secondary dark:text-secondary-dark text-sm">当日暂无交易记录</div>`
      return
    }

    // 存储entries供删除后更新使用
    this.currentEntries = entries
    this.entriesContainer = container

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

      // 备注：只显示用户填写的备注（HTML转义）
      const noteHtml = entry.note ? `<span class="truncate">${escapeHtml(entry.note)}</span>` : ""

      // 操作按钮HTML
      const entryId = escapeHtml(entry.id)
      const entryDisplayName = escapeHtml(entry.display_name || '')
      const editBtnHtml = `<button type="button" data-action="edit" data-entry-id="${entryId}" class="p-1 rounded hover:bg-surface dark:hover:bg-surface-dark text-secondary dark:text-secondary-dark hover:text-primary transition-smooth">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
      </button>`
      const deleteBtnHtml = `<button type="button" data-action="delete" data-entry-id="${entryId}" data-entry-name="${entryDisplayName}" class="p-1 rounded hover:bg-expense-light text-secondary dark:text-secondary-dark hover:text-expense transition-smooth">
        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
      </button>`

      // 转义动态内容防止XSS
      const safeDate = escapeHtml(entry.date || "")
      const safeDateShort = escapeHtml(entry.date?.slice(5) || "")
      const safeDisplayType = escapeHtml(entry.display_type || "")
      const safeDisplayName = escapeHtml(entry.display_name || "-")

      return `
        <div class="hidden lg:flex items-center py-1.5 px-4 border-b border-border/50 dark:border-border-dark/50 hover:bg-surface-hover dark:hover:bg-surface-dark-hover transition-smooth" data-entry-id="${entryId}">
          <div class="shrink-0 text-xs text-secondary dark:text-secondary-dark truncate pr-2" style="width: 80px;">${safeDate}</div>
          <div class="shrink-0 truncate flex items-center gap-2 pr-2" style="width: 150px;">
            <span class="shrink-0 inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${typeBadgeCls}">${safeDisplayType}</span>
            <span class="text-sm font-medium text-primary dark:text-primary-dark truncate">${safeDisplayName}</span>
          </div>
          <div class="shrink-0 text-right text-sm font-medium truncate" style="width: 80px;">${inflowHtml}</div>
          <div class="shrink-0 text-right text-sm font-medium truncate" style="width: 80px;">${outflowHtml}</div>
          <div class="flex-1 min-w-0 text-xs text-secondary dark:text-secondary-dark truncate ml-4">${noteHtml}</div>
          <div class="shrink-0 flex items-center justify-center gap-1.5" style="width: 70px;">
            ${editBtnHtml}
            ${deleteBtnHtml}
          </div>
        </div>
        <!-- 移动端 -->
        <div class="lg:hidden flex gap-2 items-center py-2 px-4 border-b border-border/50 dark:border-border-dark/50 hover:bg-surface-hover dark:hover:bg-surface-dark-hover transition-smooth" data-mobile-entry-id="${entryId}">
          <div class="shrink-0 text-xs text-secondary dark:text-secondary-dark">${safeDateShort}</div>
          <div class="flex-1 min-w-0 flex flex-col gap-0.5">
            <div class="flex items-center gap-1.5">
              <span class="shrink-0 inline-flex items-center px-1 py-0.5 rounded text-[10px] font-medium ${typeBadgeCls}">${safeDisplayType}</span>
              <span class="text-sm font-medium text-primary dark:text-primary-dark truncate">${safeDisplayName}</span>
            </div>
            <div class="text-xs text-secondary dark:text-secondary-dark truncate pl-4">${noteHtml}</div>
          </div>
          <div class="text-right shrink-0 flex flex-col gap-1 items-end">
            <p class="text-sm font-medium ${isIncome ? 'text-income' : 'text-expense'}">${isIncome ? '+' : '-'}${amountText}</p>
            <div class="flex gap-1">
              ${editBtnHtml}
              ${deleteBtnHtml}
            </div>
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

  // 删除后更新合计
  updateTotalAfterDelete(deletedId) {
    if (!this.currentEntries) return

    // 移除已删除的entry
    this.currentEntries = this.currentEntries.filter(e => e.id != deletedId)

    // 重新计算合计
    const totalAmount = this.currentEntries.reduce((sum, e) => {
      const amountValue = parseFloat(e.display_amount) || 0
      const amount = e.display_amount_type === "INCOME" ? amountValue : -amountValue
      return sum + amount
    }, 0)

    const modal = this.getModal()
    const totalEl = modal?.querySelector('[data-detail-total]')
    if (totalEl) {
      totalEl.textContent = `${this.currentEntries.length} 笔交易，合计 ¥${Math.abs(totalAmount).toFixed(2)}`
    }
  }

  bindCloseEvents(modal) {
    // 移除旧的事件处理器
    if (this.closeHandlers) {
      this.closeHandlers.forEach(({ el, handler, event }) => {
        el.removeEventListener(event, handler)
      })
    }

    this.closeHandlers = []

    // 关闭按钮
    const closeBtn = modal.querySelector('[data-detail-close]')
    if (closeBtn) {
      const handler = () => this.close()
      closeBtn.addEventListener("click", handler)
      this.closeHandlers.push({ el: closeBtn, handler, event: "click" })
    }

    // 点击遮罩层关闭
    const overlayBg = modal.querySelector('[data-detail-overlay]')
    if (overlayBg) {
      const handler = () => this.close()
      overlayBg.addEventListener("click", handler)
      this.closeHandlers.push({ el: overlayBg, handler, event: "click" })
    }

    // 阻止内容区域点击冒泡到遮罩层
    const contentArea = modal.querySelector('[data-detail-content]')
    if (contentArea) {
      const handler = (e) => e.stopPropagation()
      contentArea.addEventListener("click", handler)
      this.closeHandlers.push({ el: contentArea, handler, event: "click" })
    }
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