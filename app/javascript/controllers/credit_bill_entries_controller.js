import { Controller } from "@hotwired/stimulus"
import { renderEntryCards, renderLoading, renderError } from "entry_card_renderer"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.onRender = this.onRender.bind(this)
    this.onLoading = this.onLoading.bind(this)
    this.onError = this.onError.bind(this)

    this.element.addEventListener("credit-bill-entries:render", this.onRender)
    this.element.addEventListener("credit-bill-entries:loading", this.onLoading)
    this.element.addEventListener("credit-bill-entries:error", this.onError)
    this.element.dataset.creditBillEntriesReady = "true"
  }

  disconnect() {
    this.element.removeEventListener("credit-bill-entries:render", this.onRender)
    this.element.removeEventListener("credit-bill-entries:loading", this.onLoading)
    this.element.removeEventListener("credit-bill-entries:error", this.onError)
    delete this.element.dataset.creditBillEntriesReady
  }

  render(entries) {
    renderEntryCards(this.containerTarget, entries, {
      onEdit: (id) => {
        if (window.openEditTransactionModal) window.openEditTransactionModal(id)
      },
      onDelete: (id, name) => {
        if (window.confirmDeleteTransaction) window.confirmDeleteTransaction(id, name)
      },
      emptyMessage: "该期暂无交易记录"
    })
  }

  showLoading() {
    renderLoading(this.containerTarget)
  }

  showError(message = "加载失败") {
    renderError(this.containerTarget, { errorMessage: message })
  }

  onRender(event) {
    this.render(event.detail?.entries || [])
  }

  onLoading() {
    this.showLoading()
  }

  onError(event) {
    this.showError(event.detail?.message || "加载失败")
  }
}