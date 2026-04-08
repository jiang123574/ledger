import { formatMoney, formatCurrencyRaw } from "bill_formatters"

<<<<<<< HEAD
const ENTRY_CARD_TEMPLATE_DESKTOP = `
<div class="hidden lg:grid grid-cols-[2fr_3fr_2fr_2fr_2fr_2fr_1fr] gap-2 items-center py-1.5 px-3 hover:bg-surface-hover dark:hover:bg-surface-dark-hover transition-smooth" data-entry-id="" data-date="" draggable="false">
  <div class="text-xs text-secondary dark:text-secondary-dark truncate" data-field="date"></div>
  <div class="truncate flex items-center gap-2">
    <span data-field="type" class="shrink-0"></span>
    <span class="text-sm font-medium text-primary dark:text-primary-dark truncate" data-field="name"></span>
  </div>
  <div class="text-right text-sm font-medium truncate" data-field="inflow"></div>
  <div class="text-right text-sm font-medium truncate" data-field="outflow"></div>
  <div class="text-right text-xs text-secondary dark:text-secondary-dark truncate" data-field="balance"></div>
  <div class="text-xs text-secondary dark:text-secondary-dark truncate" data-field="account"></div>
  <div class="flex items-center gap-1 shrink-0 justify-center">
    <button type="button" data-role="edit" class="p-1.5 rounded-lg hover:bg-surface-hover dark:hover:bg-surface-dark-hover text-secondary dark:text-secondary-dark hover:text-primary transition-smooth">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
    </button>
    <button type="button" data-role="delete" class="p-1.5 rounded-lg hover:bg-expense-light text-secondary dark:text-secondary-dark hover:text-expense transition-smooth">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
    </button>
  </div>
</div>
`

const ENTRY_CARD_TEMPLATE_MOBILE = `
<div class="lg:hidden flex gap-3 items-center py-1.5 px-3 hover:bg-surface-hover dark:hover:bg-surface-dark-hover transition-smooth" data-mobile-entry-id="" data-date="" draggable="false">
  <div class="shrink-0 text-xs text-secondary dark:text-secondary-dark w-20" data-field="date"></div>
  <div class="flex-1 min-w-0 flex items-center gap-2">
    <span data-field="type" class="shrink-0"></span>
    <span class="text-sm font-medium text-primary dark:text-primary-dark truncate" data-field="name"></span>
  </div>
  <div class="text-right shrink-0">
    <p class="text-sm font-medium" data-field="amount"></p>
    <p class="text-xs text-secondary dark:text-secondary-dark">
      <span>余额:</span>
      <span data-field="balance-mobile"></span>
    </p>
  </div>
  <div class="flex items-center gap-1 shrink-0">
    <button type="button" data-role="edit-mobile" class="p-1.5 rounded-lg hover:bg-surface-hover dark:hover:bg-surface-dark-hover text-secondary dark:text-secondary-dark hover:text-primary transition-smooth">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
    </button>
    <button type="button" data-role="delete-mobile" class="p-1.5 rounded-lg hover:bg-expense-light text-secondary dark:text-secondary-dark hover:text-expense transition-smooth">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
    </button>
=======
const ENTRY_CARD_TEMPLATE = `
<div class="hover:bg-surface-hover dark:hover:bg-surface-dark-hover transition-smooth" data-entry-id="" data-date="" draggable="false">
  <!-- 统一响应式布局（弹性容器用于移动端，网格用于桌面端） -->
  <div class="flex lg:grid lg:grid-cols-[2fr_3fr_2fr_2fr_2fr_2fr_1fr] gap-3 lg:gap-2 items-center py-1.5 px-3 lg:py-1.5 lg:px-3">
    <!-- 日期 -->
    <div class="shrink-0 text-xs text-secondary dark:text-secondary-dark w-16 lg:w-auto" data-field="date"></div>
    
    <!-- 分类/备注区域 -->
    <div class="flex-1 lg:block min-w-0">
      <!-- 移动端：类型 + 名称（单行） -->
      <div class="lg:hidden flex items-center gap-2">
        <span data-field="type" class="shrink-0"></span>
        <p class="text-sm font-medium text-primary dark:text-primary-dark truncate" data-field="name"></p>
      </div>
      
      <!-- 桌面端：类型 + 分类（单行） -->
      <div class="hidden lg:flex lg:items-center lg:gap-2">
        <span data-field="type"></span>
        <span class="text-sm font-medium text-primary dark:text-primary-dark" data-field="name-desktop"></span>
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
      <button type="button" data-role="delete-mobile" class="p-1.5 rounded-lg hover:bg-expense-light text-secondary dark:text-secondary-dark hover:text-expense transition-smooth">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
      </button>
    </div>
>>>>>>> origin/main
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
  const fragment = document.createDocumentFragment()
  
  const typeBadgeCls = typeBadgeClass(entry.display_type)
  const amountCls = amountClass(entry.display_amount_type)
  const amountText = formatMoney(Math.abs(entry.display_amount || 0))
  const isTransfer = entry.display_type === "转账" || entry.display_type === "转入" || entry.display_type === "转出"
  const isIncome = entry.display_amount_type === "INCOME"

  // 桌面端卡片
  const desktopTemplate = document.createElement("template")
  desktopTemplate.innerHTML = ENTRY_CARD_TEMPLATE_DESKTOP.trim()
  const desktopRow = desktopTemplate.content.firstElementChild.cloneNode(true)
  desktopRow.dataset.entryId = entry.id
  desktopRow.dataset.date = entry.date || ''
  desktopRow.draggable = true

  desktopRow.querySelector('[data-field="date"]').textContent = entry.date || ""
  
  const typeEl = desktopRow.querySelector('[data-field="type"]')
  typeEl.textContent = entry.display_type || ""
  typeEl.className = `shrink-0 inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${typeBadgeCls}`
  
<<<<<<< HEAD
  const nameEl = desktopRow.querySelector('[data-field="name"]')
  if (isTransfer && entry.transfer_from && entry.transfer_to) {
    nameEl.textContent = `${entry.transfer_from} → ${entry.transfer_to}`
=======
  // 分类名（移动端）
  const nameEl = row.querySelector('[data-field="name"]')
  if (isTransfer) {
    nameEl.style.display = 'none'
>>>>>>> origin/main
  } else {
    nameEl.textContent = entry.display_name || "-"
  }

<<<<<<< HEAD
  const inflowEl = desktopRow.querySelector('[data-field="inflow"]')
  const outflowEl = desktopRow.querySelector('[data-field="outflow"]')
=======
  // 分类名（桌面端）
  const nameDesktopEl = row.querySelector('[data-field="name-desktop"]')
  if (isTransfer) {
    nameDesktopEl.style.display = 'none'
  } else {
    nameDesktopEl.textContent = entry.display_name || "-"
  }

  // 流入/流出
  const inflowEl = row.querySelector('[data-field="inflow"]')
  const outflowEl = row.querySelector('[data-field="outflow"]')
>>>>>>> origin/main
  
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

  desktopRow.querySelector('[data-field="balance"]').textContent = formatCurrencyRaw(entry.balance_after || 0)
  
  const accountEl = desktopRow.querySelector('[data-field="account"]')
  if (isTransfer && entry.transfer_from && entry.transfer_to) {
    accountEl.textContent = `${entry.transfer_from} → ${entry.transfer_to}`
  } else {
    accountEl.textContent = entry.account_name || "未知账户"
  }

  const editBtn = desktopRow.querySelector('[data-role="edit"]')
  const deleteBtn = desktopRow.querySelector('[data-role="delete"]')
  if (editBtn && options.onEdit) {
    editBtn.addEventListener("click", () => options.onEdit(entry.id))
  }
  if (deleteBtn && options.onDelete) {
    deleteBtn.addEventListener("click", () => options.onDelete(entry.id, entry.display_name || ""))
  }

  // 移动端卡片
  const mobileTemplate = document.createElement("template")
  mobileTemplate.innerHTML = ENTRY_CARD_TEMPLATE_MOBILE.trim()
  const mobileRow = mobileTemplate.content.firstElementChild.cloneNode(true)
  mobileRow.dataset.mobileEntryId = entry.id
  mobileRow.dataset.date = entry.date || ''
  mobileRow.draggable = false

  mobileRow.querySelector('[data-field="date"]').textContent = entry.date || ""
  
  const mobileTypeEl = mobileRow.querySelector('[data-field="type"]')
  mobileTypeEl.textContent = entry.display_type || ""
  mobileTypeEl.className = `shrink-0 inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${typeBadgeCls}`
  
  const mobileNameEl = mobileRow.querySelector('[data-field="name"]')
  if (isTransfer && entry.transfer_from && entry.transfer_to) {
    mobileNameEl.textContent = `${entry.transfer_from} → ${entry.transfer_to}`
  } else {
    mobileNameEl.textContent = entry.display_name || "-"
  }

  const amountEl = mobileRow.querySelector('[data-field="amount"]')
  if (isTransfer && entry.show_both_amounts) {
    amountEl.innerHTML = `<span class="text-expense">-${amountText}</span><span class="mx-1 text-secondary dark:text-secondary-dark">/</span><span class="text-income">+${amountText}</span>`
  } else {
    amountEl.textContent = amountText
    amountEl.className = `text-sm font-medium ${amountCls}`
  }

  mobileRow.querySelector('[data-field="balance-mobile"]').textContent = formatCurrencyRaw(entry.balance_after || 0)

  const editMobileBtn = mobileRow.querySelector('[data-role="edit-mobile"]')
  const deleteMobileBtn = mobileRow.querySelector('[data-role="delete-mobile"]')
  if (editMobileBtn && options.onEdit) {
    editMobileBtn.addEventListener("click", () => options.onEdit(entry.id))
  }
  if (deleteMobileBtn && options.onDelete) {
    deleteMobileBtn.addEventListener("click", () => options.onDelete(entry.id, entry.display_name || ""))
  }

  fragment.appendChild(desktopRow)
  fragment.appendChild(mobileRow)
  
  return fragment
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
  template: ENTRY_CARD_TEMPLATE_DESKTOP,
  typeBadgeClass,
  amountClass,
  createEntryCard,
  renderEntryCards,
  renderLoading,
  renderError
}

export {
  ENTRY_CARD_TEMPLATE_DESKTOP,
  ENTRY_CARD_TEMPLATE_MOBILE,
  typeBadgeClass,
  amountClass,
  createEntryCard,
  renderEntryCards,
  renderLoading,
  renderError
}