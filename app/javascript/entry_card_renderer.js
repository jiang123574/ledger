import { formatMoney, formatCurrencyRaw } from "bill_formatters"

const ENTRY_CARD_TEMPLATE = `
<div class="hover:bg-surface-hover dark:hover:bg-surface-dark-hover transition-smooth" data-entry-id="" data-date="" draggable="false">
  <!-- 统一响应式布局（弹性容器用于移动端，网格用于桌面端） -->
  <div class="flex lg:grid lg:grid-cols-[2fr_3fr_2fr_2fr_2fr_2fr_1fr] gap-3 lg:gap-2 items-center py-1.5 px-3 lg:py-1.5 lg:px-3">
    <!-- 日期 -->
    <div class="shrink-0 text-xs text-secondary dark:text-secondary-dark w-16 lg:w-auto" data-field="date"></div>
    
    <!-- 分类/备注区域 -->
    <div class="flex-1 lg:block min-w-0">
      <!-- 移动端：类型 + 分类/名称 + 备注 -->
      <div class="lg:hidden flex items-center gap-2 mb-0.5">
        <span data-field="type" class="shrink-0"></span>
        <p class="text-sm font-medium text-primary dark:text-primary-dark truncate" data-field="name"></p>
      </div>
      <p class="lg:hidden text-xs text-secondary dark:text-secondary-dark truncate" data-field="note"></p>
      
      <!-- 桌面端：类型 + 分类（单行） -->
      <div class="hidden lg:flex lg:items-center lg:gap-2">
        <span data-field="type"></span>
        <span class="text-sm font-medium text-primary dark:text-primary-dark" data-field="name"></span>
      </div>
    </div>
    
    <!-- 流入 - 桌面端显示 -->
    <div class="hidden lg:block text-right text-sm font-medium pr-2" data-field="inflow"></div>
    
    <!-- 流出 - 桌面端显示 -->
    <div class="hidden lg:block text-right text-sm font-medium pr-2" data-field="outflow"></div>
    
    <!-- 右侧区域（移动端） / 余额列（桌面端） -->
    <div class="text-right shrink-0 lg:block">
      <!-- 移动端：显示金额 -->
      <p class="lg:hidden text-sm font-medium" data-field="amount"></p>
      <!-- 桌面端 & 移动端：余额 -->
      <p class="text-xs text-secondary dark:text-secondary-dark">
        <span class="lg:hidden">余额:</span>
        <span data-field="balance"></span>
      </p>
    </div>
    
    <!-- 账户 - 桌面端显示 -->
    <div class="hidden lg:block text-xs text-secondary dark:text-secondary-dark truncate" data-field="account"></div>
    
    <!-- 操作按钮 -->
    <div class="flex items-center gap-1 shrink-0 lg:justify-center">
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

  const typeBadgeCls = typeBadgeClass(entry.display_type)
  const amountCls = amountClass(entry.display_amount_type)
  const amountText = formatMoney(Math.abs(entry.display_amount || 0))
  const isTransfer = entry.display_type === "转账" || entry.display_type === "转入" || entry.display_type === "转出"
  const isIncome = entry.display_amount_type === "INCOME"

  // 统一字段填充
  row.querySelector('[data-field="date"]').textContent = entry.date || ""
  
  // 类型标签
  const typeEl = row.querySelector('[data-field="type"]')
  typeEl.textContent = entry.display_type || ""
  typeEl.className = `inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${typeBadgeCls}`
  
  // 分类名（转账不显示）
  const nameEl = row.querySelector('[data-field="name"]')
  if (isTransfer) {
    nameEl.style.display = 'none'
  } else {
    nameEl.textContent = entry.display_name || "-"
  }

  // 备注 - 仅在移动端显示
  const noteEl = row.querySelector('[data-field="note"]')
  if (isTransfer && entry.transfer_from && entry.transfer_to) {
    noteEl.textContent = `${entry.transfer_from} → ${entry.transfer_to}`
  } else {
    noteEl.textContent = entry.note || entry.account_name || ""
  }

  // 流入/流出
  const inflowEl = row.querySelector('[data-field="inflow"]')
  const outflowEl = row.querySelector('[data-field="outflow"]')
  
  if (isTransfer && entry.show_both_amounts) {
    inflowEl.innerHTML = `<span class="text-income">+${amountText}</span>`
    outflowEl.innerHTML = `<span class="text-expense">-${amountText}</span>`
  } else if (isIncome) {
    inflowEl.innerHTML = `<span class="text-income">+${amountText}</span>`
    outflowEl.innerHTML = ""
  } else {
    inflowEl.innerHTML = ""
    outflowEl.innerHTML = `<span class="text-expense">-${amountText}</span>`
  }

  // 余额
  row.querySelector('[data-field="balance"]').textContent = formatCurrencyRaw(entry.balance_after || 0)

  // 移动端金额展示
  const amountEl = row.querySelector('[data-field="amount"]')
  if (isTransfer && entry.show_both_amounts) {
    amountEl.innerHTML = `<span class="text-expense">-${amountText}</span><span class="mx-1 text-secondary dark:text-secondary-dark">/</span><span class="text-income">+${amountText}</span>`
  } else {
    amountEl.textContent = amountText
    amountEl.className = `text-sm font-medium ${amountCls}`
  }

  // 账户（转账显示来源→目标）
  const accountEl = row.querySelector('[data-field="account"]')
  if (isTransfer && entry.transfer_from && entry.transfer_to) {
    accountEl.textContent = `${entry.transfer_from} → ${entry.transfer_to}`
  } else {
    accountEl.textContent = entry.account_name || "未知账户"
  }

  // 按钮事件
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
