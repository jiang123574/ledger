import { Controller } from "@hotwired/stimulus"
import { renderEntryCards, renderLoading, renderError } from "entry_card_renderer"

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
      renderLoading(container, {
        loadingMessage: "加载交易明细..."
      })
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

      // 渲染交易卡片
      if (container) {
        const transactionModalController = this.getTransactionModalController()
        renderEntryCards(container, entries, {
          onEdit: (id) => {
            if (transactionModalController) {
              transactionModalController.openEditTransactionModal({ params: { id } })
            }
          },
          onDelete: (id, name) => {
            if (transactionModalController) {
              transactionModalController.confirmDeleteTransaction({ params: { id, name } })
            }
          },
          dragEnabled: false,
          emptyMessage: "该分类暂无交易记录"
        })
      }

    } catch (error) {
      console.error("加载分类明细失败:", error)
      if (container) {
        renderError(container, {
          errorMessage: "加载失败，请重试"
        })
      }
    }
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
    const overlayBg = modal.querySelector('.modal-overlay-bg')
    if (overlayBg) {
      const handler = (e) => {
        if (e.target === overlayBg) this.close()
      }
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