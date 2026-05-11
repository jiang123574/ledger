import { Controller } from "@hotwired/stimulus"
import { renderEntryCards, renderLoading, renderError } from "entry_card_renderer"

// 分类明细展示控制器
// 点击分类行后，弹窗展示该分类在该时间段的所有交易记录

export default class extends Controller {
  static targets = ["modal", "container", "title", "total", "closeBtn"]
  static values = {
    startDate: String,
    endDate: String
  }

  connect() {
    // 绑定关闭按钮和点击外部关闭
    if (this.hasCloseBtnTarget) {
      this.closeBtnTarget.addEventListener("click", () => this.close())
    }

    // ESC 键关闭
    this.handleEsc = (e) => {
      if (e.key === "Escape" && this.hasModalTarget && !this.modalTarget.classList.contains("hidden")) {
        this.close()
      }
    }
    document.addEventListener("keydown", this.handleEsc)

    // 点击遮罩层关闭
    if (this.hasModalTarget) {
      this.modalTarget.addEventListener("click", (e) => {
        if (e.target === this.modalTarget) {
          this.close()
        }
      })
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleEsc)
  }

  // 点击分类行，显示明细
  async show(event) {
    const row = event.currentTarget
    const categoryId = row.dataset.categoryId
    const categoryName = row.querySelector(".text-sm.font-medium")?.textContent || "分类明细"

    if (!categoryId) return

    // 显示弹窗和加载状态
    this.modalTarget.classList.remove("hidden")
    this.titleTarget.textContent = categoryName

    renderLoading(this.containerTarget, {
      loadingMessage: "加载交易明细..."
    })

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
      this.totalTarget.textContent = `${entries.length} 笔交易，合计 ¥${Math.abs(totalAmount).toFixed(2)}`

      // 渲染交易卡片
      const transactionModalController = this.getTransactionModalController()
      renderEntryCards(this.containerTarget, entries, {
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

    } catch (error) {
      console.error("加载分类明细失败:", error)
      renderError(this.containerTarget, {
        errorMessage: "加载失败，请重试"
      })
    }
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
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