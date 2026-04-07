import { formatMoney, formatCurrencyRaw } from "bill_formatters"

const ENTRY_CARD_TEMPLATE = `
<div class="p-3 hover:bg-surface-hover dark:hover:bg-surface-dark-hover transition-smooth">
  <div class="flex items-center gap-3">
    <div class="shrink-0 text-xs text-secondary dark:text-secondary-dark w-20" data-field="date"></div>
    <div class="flex-1 min-w-0">
      <div class="flex items-center gap-2">
        <span data-field="type"></span>
        <p class="text-sm font-medium text-primary dark:text-primary-dark truncate" data-field="name"></p>
      </div>
      <p class="text-xs text-secondary dark:text-secondary-dark truncate mt-0.5" data-field="note"></p>
    </div>
    <div class="text-right shrink-0">
      <p data-field="amount"></p>
      <p class="text-xs text-secondary dark:text-secondary-dark" data-field="balance"></p>
    </div>
    <div class="flex items-center gap-1 shrink-0">
      <button type="button" data-role="edit" class="p-1.5 rounded-lg hover:bg-surface-hover dark:hover:bg-surface-dark-hover text-secondary dark:text-secondary-dark hover:text-primary transition-smooth">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
      </button>
      <button type="button" data-role="delete" class="p-1.5 rounded-lg hover:bg-expense-light text-secondary dark:text-secondary-dark hover:text-expense transition-smooth">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
      </button>
    </div>
  </div>
</div>
`

function typeBadgeClass(displayType) {
  const classes = {
    "收入": "bg-income-light text-income",
    "转入": "bg-income-light text-income",
    "支出": "bg-expense-light text-expense",
    "转出": "bg-expense-light text-expense",
    "转账": "bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300"
  }
  return classes[displayType] || "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300"
}

function amountClass(displayAmountType) {
  return displayAmountType === "INCOME" ? "text-income" : "text-expense"
}

function createEntryCard(entry, options = {}) {
  const template = document.createElement("template")
  template.innerHTML = ENTRY_CARD_TEMPLATE.trim()
  const row = template.content.firstElementChild.cloneNode(true)
  row.dataset.entryId = entry.id
  row.dataset.date = entry.date || ''
  row.draggable = true
  row.classList.add('cursor-move')

  const typeBadgeCls = typeBadgeClass(entry.display_type)
  const amountCls = amountClass(entry.display_amount_type)
  const amountText = formatMoney(Math.abs(entry.display_amount || 0))

  row.querySelector('[data-field="date"]').textContent = entry.date || ""
  row.querySelector('[data-field="type"]').textContent = entry.display_type || ""
  row.querySelector('[data-field="type"]').className = `inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${typeBadgeCls}`
  row.querySelector('[data-field="name"]').textContent = entry.display_name || "-"
  row.querySelector('[data-field="note"]').textContent = entry.note || ""

  const amountField = row.querySelector('[data-field="amount"]')
  if (entry.display_type === "转账" && entry.show_both_amounts) {
    amountField.innerHTML = `<span class="text-expense">-${amountText}</span><span class="mx-1 text-secondary dark:text-secondary-dark">/</span><span class="text-income">+${amountText}</span>`
    amountField.className = "text-sm"
  } else {
    amountField.textContent = amountText
    amountField.className = `text-sm font-medium ${amountCls}`
  }

  row.querySelector('[data-field="balance"]').textContent = `余额: ${formatCurrencyRaw(entry.balance_after || 0)}`

  const editButton = row.querySelector('[data-role="edit"]')
  const deleteButton = row.querySelector('[data-role="delete"]')

  if (editButton && options.onEdit) {
    editButton.addEventListener("click", () => options.onEdit(entry.id))
  }
  if (deleteButton && options.onDelete) {
    deleteButton.addEventListener("click", () => options.onDelete(entry.id, entry.display_name || ""))
  }

  return row
}

function renderEntryCards(container, entries, options = {}) {
  container.innerHTML = ""

  if (!entries || entries.length === 0) {
    const emptyNode = document.createElement("div")
    emptyNode.className = options.emptyClass || "p-8 text-center text-secondary dark:text-secondary-dark text-sm"
    emptyNode.textContent = options.emptyMessage || "暂无交易记录"
    container.appendChild(emptyNode)
    return
  }

  entries.forEach(entry => {
    const card = createEntryCard(entry, options)
    container.appendChild(card)
  })
}

function renderLoading(container, options = {}) {
  container.innerHTML = ""
  const node = document.createElement("div")
  node.className = options.loadingClass || "p-4 text-center text-secondary dark:text-secondary-dark text-sm"
  node.textContent = options.loadingMessage || "加载中..."
  container.appendChild(node)
}

function renderError(container, options = {}) {
  container.innerHTML = ""
  const node = document.createElement("div")
  node.className = options.errorClass || "p-4 text-center text-red-500 text-sm"
  node.textContent = options.errorMessage || "加载失败"
  container.appendChild(node)
}

window.EntryCardRenderer = {
  template: ENTRY_CARD_TEMPLATE,
  typeBadgeClass,
  amountClass,
  createEntryCard,
  renderEntryCards,
  renderLoading,
  renderError
}

export {
  ENTRY_CARD_TEMPLATE,
  typeBadgeClass,
  amountClass,
  createEntryCard,
  renderEntryCards,
  renderLoading,
  renderError
}
