import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "checkbox", "page", "group", "selectionBar"]
  static values = {
    selectedIds: Array,
    paramName: { type: String, default: "ids" }
  }

  connect() {
    this.updateView()
  }

  toggleRowSelection(event) {
    const checkbox = event.target
    const id = checkbox.value

    if (checkbox.checked) {
      if (!this.selectedIdsValue.includes(id)) {
        this.selectedIdsValue = [...this.selectedIdsValue, id]
      }
    } else {
      this.selectedIdsValue = this.selectedIdsValue.filter((i) => i !== id)
    }
  }

  togglePageSelection(event) {
    const checkbox = event.target
    const pageValue = checkbox.dataset.bulkSelectPageValue

    if (!pageValue) return

    const pageCheckboxes = this.element.querySelectorAll(
      `[data-bulk-select-page-value="${pageValue}"]`
    )

    if (checkbox.checked) {
      pageCheckboxes.forEach((cb) => {
        cb.checked = true
      })

      const pageIds = Array.from(pageCheckboxes).map((cb) => cb.value)
      this.selectedIdsValue = [...new Set([...this.selectedIdsValue, ...pageIds])]
    } else {
      pageCheckboxes.forEach((cb) => {
        cb.checked = false
      })

      const pageIds = Array.from(pageCheckboxes).map((cb) => cb.value)
      this.selectedIdsValue = this.selectedIdsValue.filter(
        (id) => !pageIds.includes(id)
      )
    }
  }

  toggleGroupSelection(event) {
    const checkbox = event.target
    const groupValue = checkbox.dataset.bulkSelectGroupValue

    if (!groupValue) return

    const groupCheckboxes = this.element.querySelectorAll(
      `[data-bulk-select-group-value="${groupValue}"]`
    )

    if (checkbox.checked) {
      groupCheckboxes.forEach((cb) => {
        cb.checked = true
      })

      const groupIds = Array.from(groupCheckboxes).map((cb) => cb.value)
      this.selectedIdsValue = [...new Set([...this.selectedIdsValue, ...groupIds])]
    } else {
      groupCheckboxes.forEach((cb) => {
        cb.checked = false
      })

      const groupIds = Array.from(groupCheckboxes).map((cb) => cb.value)
      this.selectedIdsValue = this.selectedIdsValue.filter(
        (id) => !groupIds.includes(id)
      )
    }
  }

  selectedIdsValueChanged() {
    this.updateView()
  }

  updateView() {
    this.updateCheckboxes()
    this.updateSelectionBar()
  }

  updateCheckboxes() {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = this.selectedIdsValue.includes(checkbox.value)
    })
  }

  updateSelectionBar() {
    if (!this.hasSelectionBarTarget) return

    const selectionBar = this.selectionBarTarget
    const count = this.selectedIdsValue.length

    if (count === 0) {
      selectionBar.classList.add("hidden")
    } else {
      selectionBar.classList.remove("hidden")
      const countElement = selectionBar.querySelector("[data-bulk-select-count]")
      if (countElement) {
        countElement.textContent = count
      }
    }
  }

  selectAll(event) {
    event.preventDefault()

    const allIds = this.checkboxTargets.map((cb) => cb.value)
    this.selectedIdsValue = allIds
  }

  clearSelection(event) {
    event.preventDefault()
    this.selectedIdsValue = []
  }

  submitBulkAction(event) {
    event.preventDefault()

    const form = event.target.closest("form")
    if (!form) return

    this.selectedIdsValue.forEach((id) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = this.paramNameValue
      input.value = id
      form.appendChild(input)
    })

    form.requestSubmit()
  }
}
