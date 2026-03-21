import { Controller } from "@hotwired/stimulus"

/**
 * List Filter Controller - Filter list items by search input
 *
 * Usage:
 *   <div data-controller="list-filter">
 *     <input data-list-filter-target="input" data-action="input->list-filter#filter">
 *     <div data-list-filter-target="list">
 *       <div class="filterable-item" data-filter-name="Apple">Apple</div>
 *       <div class="filterable-item" data-filter-name="Banana">Banana</div>
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["input", "list"]

  filter() {
    const query = this.inputTarget.value.toLowerCase().trim()
    const items = this.listTarget.querySelectorAll(".filterable-item")

    items.forEach(item => {
      const filterName = (item.dataset.filterName || item.textContent).toLowerCase()
      const matches = filterName.includes(query)
      item.classList.toggle("hidden", !matches)
    })
  }
}