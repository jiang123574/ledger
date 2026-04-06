import { Controller } from "@hotwired/stimulus"
import { renderEntryCards, renderLoading, renderError } from "entry_card_renderer"

export default class extends Controller {
  static targets = ["container"]
  static values = {
    accountId: String,
    page: Number,
    perPage: Number,
    totalCount: Number,
    periodType: String,
    periodValue: String,
    filterType: String,
    search: String,
    categoryIds: String
  }

  connect() {
    this.isLoading = false
    this.currentPage = this.pageValue
    this.setupIntersectionObserver()
    window.loadMoreEntries = () => {
      if (!this.isLoading) {
        this.loadMore()
      }
    }
  }

  setupLoadMoreButton() {
    // Button click is handled via onclick attribute in HTML
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  setupIntersectionObserver() {
    const sentinel = document.getElementById("load-more-sentinel")
    if (!sentinel) return

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting && !this.isLoading) {
          this.loadMore()
        }
      })
    }, { rootMargin: "100px" })

    this.observer.observe(sentinel)
  }

  loadMore() {
    if (this.isLoading) return

    const totalPages = Math.ceil(this.totalCountValue / this.perPageValue)
    if (this.currentPage >= totalPages) {
      document.getElementById("load-more-sentinel")?.classList.add("hidden")
      return
    }

    this.isLoading = true
    this.showLoadingIndicator()

    const nextPage = this.currentPage + 1
    this.fetchEntries(nextPage)
  }

  fetchEntries(page) {
    const params = new URLSearchParams()
    params.set("page", page)
    params.set("per_page", this.perPageValue)
    params.set("format", "json")

    if (this.accountIdValue) params.set("account_id", this.accountIdValue)
    if (this.periodTypeValue) params.set("period_type", this.periodTypeValue)
    if (this.periodValueValue) params.set("period_value", this.periodValueValue)
    if (this.filterTypeValue) params.set("type", this.filterTypeValue)
    if (this.searchValue) params.set("search", this.searchValue)
    if (this.categoryIdsValue) {
      this.categoryIdsValue.split(",").forEach((id) => {
        if (id) params.append("category_ids[]", id)
      })
    }

    fetch(`/accounts/entries?${params.toString()}`, {
      headers: { "X-Requested-With": "XMLHttpRequest" }
    })
      .then((r) => r.json())
      .then((data) => {
        this.appendEntries(data.entries)
        this.currentPage = page
        this.hideLoadingIndicator()
        this.isLoading = false

        if (page * this.perPageValue >= this.totalCountValue) {
          document.getElementById("load-more-sentinel")?.classList.add("hidden")
        }
      })
      .catch((err) => {
        console.error("Failed to load entries:", err)
        this.hideLoadingIndicator()
        this.isLoading = false
      })
  }

  appendEntries(entries) {
    entries.forEach((entry) => {
      const card = window.EntryCardRenderer.createEntryCard(entry, {
        onEdit: (id) => {
          if (window.openEditTransactionModal) {
            window.openEditTransactionModal(id)
          } else {
            console.warn("openEditTransactionModal not found")
          }
        },
        onDelete: (id, name) => {
          if (window.confirmDeleteTransaction) {
            window.confirmDeleteTransaction(id, name)
          } else {
            console.warn("confirmDeleteTransaction not found")
          }
        }
      })
      this.containerTarget.appendChild(card)
    })
  }

  showLoadingIndicator() {
    document.getElementById("load-more-btn")?.classList.add("hidden")
    document.getElementById("loading-indicator")?.classList.remove("hidden")
  }

  hideLoadingIndicator() {
    document.getElementById("load-more-btn")?.classList.remove("hidden")
    document.getElementById("loading-indicator")?.classList.add("hidden")
  }
}
