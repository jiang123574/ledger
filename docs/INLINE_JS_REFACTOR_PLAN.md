# Inline JS 重构计划

## 背景

当前 `accounts/index.html.erb` 和 `reports/show.html.erb` 存在大量 inline JavaScript，不符合 Stimulus 架构风格。本计划旨在将这些代码迁移到 Stimulus controllers 中。

---

## 当前状态分析

### accounts/index.html.erb (2720行，52个 onclick)

| Script 块 | 起始行 | 行数 | 功能概要 |
|-----------|--------|------|----------|
| 第1块 | 652 | ~380 | 账户弹窗、编辑、删除、信用卡字段切换、新建交易弹窗 |
| 第2块 | 1036 | ~1614 | 时间筛选器、分类筛选弹窗、搜索、类型筛选、局部刷新、转账模式切换 |
| 第3块 | 2654 | ~45 | 信用卡账单视图模式切换（日期/账单） |

### reports/show.html.erb (1207行，10个 onclick)

| Script 块 | 起始行 | 行数 | 功能概要 |
|-----------|--------|------|----------|
| 唯1块 | 834 | ~375 | 分类筛选弹窗（localStorage）、时间选择器面板、月份/年份渲染、左右导航 |

---

## Phase 1: reports 页面优化

**预计工作量**: 2-3 小时  
**目标**: 将 ~375行 inline JS 移入 `category_stats_controller.js`

### 1.1 时间选择器功能迁移

#### 当前 inline 函数 → Controller 方法映射

| Inline 函数 | Controller 方法 | HTML 改动 |
|-------------|-----------------|-----------|
| `categoryStatsShiftPeriod(direction)` | `shiftPeriod(event)` | `data-action="click->category-stats#shiftPeriod" data-direction="-1"` |
| `toggleCategoryStatsPeriodPicker()` | `togglePicker()` | `data-action="click->category-stats#togglePicker"` |
| `categoryStatsShiftPickerYear(direction)` | `shiftPickerYear(event)` | `data-action="click->category-stats#shiftPickerYear" data-direction="-1"` |
| `categoryStatsSelectPickerMonth(month)` | `selectPickerMonth(event)` | `data-action="click->category-stats#selectPickerMonth" data-month="01"` |
| `categoryStatsSelectPickerYear(year)` | `selectPickerYear(event)` | `data-action="click->category-stats#selectPickerYear" data-year="2026"` |
| `categoryStatsUpdatePeriodDisplay()` | `updatePeriodDisplay()` | 内部方法 |
| `renderCategoryStatsMonthPicker()` | `renderMonthPicker()` | 内部方法 |
| `renderCategoryStatsYearPicker()` | `renderYearPicker()` | 内部方法 |
| `openCategoryStatsPickerPanel()` | `openPickerPanel()` | 内部方法 |
| `closeCategoryStatsPeriodPicker()` | `closePickerPanel()` | 内部方法 |

#### 新增 targets

```javascript
static targets = [
  // 现有 targets...
  "pickerPanel", "pickerYearDisplay", "pickerGrid",
  "periodDisplay"
]
```

#### 新增 values

```javascript
static values = {
  // 现有 values...
  pickerYear: Number
}
```

### 1.2 分类筛选弹窗功能迁移

#### 当前 inline 函数 → Controller 方法映射

| Inline 函数 | Controller 方法 | HTML 改动 |
|-------------|-----------------|-----------|
| 打开弹窗 (openBtn click) | `openFilterModal()` | `data-action="click->category-stats#openFilterModal"` |
| 搜索输入 | `filterSearch(event)` | `data-action="input->category-stats#filterSearch"` |
| 全选 | `selectAll()` | `data-action="click->category-stats#selectAll"` |
| 清除 | `clearAll()` | `data-action="click->category-stats#clearAll"` |
| 确认 | `confirmFilter()` | `data-action="click->category-stats#confirmFilter"` |
| `restoreFromStorage()` | `restoreFilterFromStorage()` | connect 时调用 |
| `updateVisibleCount()` | `updateFilterCount()` | 内部方法 |
| `updateButtonCount()` | `updateFilterButtonCount()` | 内部方法 |

#### 新增 targets

```javascript
static targets = [
  // 现有 targets...
  "filterModal", "filterSearchInput", "filterOption",
  "filterCountBadge"
]
```

### 1.3 HTML 改动示例

**时间导航按钮 - 改动前**:
```erb
<button onclick="categoryStatsShiftPeriod(-1)">‹</button>
<div onclick="toggleCategoryStatsPeriodPicker()">2026年4月</div>
<button onclick="categoryStatsShiftPeriod(1)">›</button>
```

**时间导航按钮 - 改动后**:
```erb
<button data-action="click->category-stats#shiftPeriod" data-direction="-1">‹</button>
<div data-action="click->category-stats#togglePicker">2026年4月</div>
<button data-action="click->category-stats#shiftPeriod" data-direction="1">›</button>
```

**月份选择按钮 - 改动前**:
```erb
<button onclick="categoryStatsSelectPickerMonth(01)">1月</button>
```

**月份选择按钮 - 改动后**:
```erb
<button data-action="click->category-stats#selectPickerMonth" data-month="01">1月</button>
```

**分类筛选按钮 - 改动前**:
```erb
<button id="open-category-stats-filter" ...>筛选分类</button>
```

**分类筛选按钮 - 改动后**:
```erb
<button data-category-stats-target="openFilterBtn" 
        data-action="click->category-stats#openFilterModal" ...>筛选分类</button>
```

---

## Phase 2: accounts 页面优化

**预计工作量**: 8-10 小时  
**目标**: 将 ~2000行 inline JS 移入多个 Stimulus controllers

### 2.1 新建 `account_modal_controller.js`

**功能**: 账户弹窗管理（新建/编辑/删除）

#### Controller 结构

```javascript
// app/javascript/controllers/account_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", "form", "title", "nameInput", "typeInput", 
    "initialBalanceInput", "includeInTotalCheckbox", "hiddenCheckbox",
    "creditCardFields", "creditLimitInput", "billingDayInput",
    "billingDayModeInput", "dueDayModeInput", "dueDayInput", "dueDayOffsetInput",
    "deleteBtnContainer"
  ]

  static values = {
    accountId: String,
    accountName: String
  }

  connect() {
    // 监听账户类型变化
    this.typeInputTarget?.addEventListener('change', this.toggleCreditCardFields.bind(this))
  }

  // 打开编辑弹窗
  openEdit(event) {
    const btn = event.currentTarget
    const id = btn.dataset.id
    const name = btn.dataset.name
    const type = btn.dataset.type
    // ... 设置各字段值
    this.modalTarget.classList.remove('hidden')
  }

  // 打开新建弹窗
  openNew() {
    this.resetForm()
    this.titleTarget.textContent = '新建账户'
    this.modalTarget.classList.remove('hidden')
  }

  // 关闭弹窗
  close() {
    this.modalTarget.classList.add('hidden')
    this.resetForm()
  }

  // 重置表单
  resetForm() {
    this.titleTarget.textContent = '新建账户'
    this.formTarget.action = '/accounts'
    this.formTarget.method = 'post'
    // ... 清空各字段
  }

  // 切换信用卡字段显示
  toggleCreditCardFields() {
    const type = this.typeInputTarget?.value
    if (type === 'CREDIT') {
      this.creditCardFieldsTarget.classList.remove('hidden')
    } else {
      this.creditCardFieldsTarget.classList.add('hidden')
    }
  }

  // 确认删除
  confirmDelete(event) {
    const id = event.currentTarget.dataset.id
    const name = event.currentTarget.dataset.name
    if (!window.confirm(`确定要删除账户 "${name}" 吗？`)) return
    // ... 创建 form 并提交删除请求
  }
}
```

#### HTML 改动

**编辑按钮 - 改动前**:
```erb
<button onclick="openEditAccountModal(this)" data-id="1" data-name="现金">编辑</button>
```

**编辑按钮 - 改动后**:
```erb
<button data-action="click->account-modal#openEdit" 
        data-account-modal-id-param="1" 
        data-account-modal-name-param="现金">编辑</button>
```

---

### 2.2 新建 `account_filter_controller.js`

**功能**: 筛选功能（时间、分类、搜索、类型）

#### Controller 结构

```javascript
// app/javascript/controllers/account_filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "searchInput", "typeFilter", "periodTypeFilter", "periodValueFilter",
    "periodDisplay", "pickerPanel", "pickerYearDisplay", "pickerGrid",
    "categoryFilterModal", "categoryFilterSearch", "categoryFilterOption",
    "categoryFilterCount", "categoryCheckbox"
  ]

  static values = {
    selectedCategoryIds: Array,
    pickerYear: Number,
    accountId: String
  }

  connect() {
    this.restoreCategoryFilterFromStorage()
    this.syncPeriodDisplay()
    this.bindEvents()
  }

  // 时间筛选 - 与 reports 页类似逻辑
  shiftPeriod(event) { ... }
  togglePicker() { ... }
  selectPickerMonth(event) { ... }
  selectPickerYear(event) { ... }

  // 分类筛选
  openCategoryFilterModal() { ... }
  filterCategoryOptions(event) { ... }
  selectAllCategories() { ... }
  clearAllCategories() { ... }
  confirmCategoryFilter() { ... }

  // 搜索和类型筛选
  applyFilters() { ... }
  clearFilters() { ... }

  // 局部刷新
  async refreshMainContent(url) { ... }

  // localStorage
  restoreCategoryFilterFromStorage() { ... }
  saveCategoryFilterToStorage() { ... }
}
```

---

### 2.3 新建 `view_mode_controller.js`

**功能**: 信用卡账单视图模式切换

#### Controller 结构

```javascript
// app/javascript/controllers/view_mode_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "billWrapper", "transactionList", "summaryBar", "filterBar",
    "dateBtn", "billBtn"
  ]

  static values = {
    mode: { type: String, default: 'date' }
  }

  connect() {
    this.modeValue = this.initialMode()
  }

  switchMode(event) {
    const mode = event.currentTarget.dataset.mode
    this.modeValue = mode
    this.updateUI()
    this.updateURL()
  }

  updateUI() {
    if (this.modeValue === 'bill') {
      this.billWrapperTarget.classList.remove('hidden')
      this.transactionListTarget.classList.add('hidden')
      // ...
    } else {
      this.billWrapperTarget.classList.add('hidden')
      this.transactionListTarget.classList.remove('hidden')
      // ...
    }
  }

  updateURL() {
    const params = new URLSearchParams(window.location.search)
    if (this.modeValue === 'bill') {
      params.set('view_mode', 'bill')
    } else {
      params.delete('view_mode')
    }
    history.replaceState({}, '', window.location.pathname + '?' + params.toString())
  }
}
```

---

### 2.4 新建 `transaction_modal_controller.js`

**功能**: 新建交易弹窗（收支/转账模式切换）

#### Controller 结构

```javascript
// app/javascript/controllers/transaction_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", "form", "typeInput",
    "categoryFieldWrapper", "categoryField",
    "targetAccountField", "accountFieldWrapper",
    "fundingAccountField"
  ]

  static values = {
    mode: { type: String, default: 'category' } // 'category' or 'transfer'
  }

  open() {
    this.modalTarget.classList.remove('hidden')
  }

  close() {
    this.modalTarget.classList.add('hidden')
    this.resetForm()
  }

  toggleTransferMode() {
    if (this.modeValue === 'transfer') {
      this.modeValue = 'category'
      this.targetAccountFieldTarget.classList.add('hidden')
      this.categoryFieldWrapperTarget.classList.remove('hidden')
    } else {
      this.modeValue = 'transfer'
      this.targetAccountFieldTarget.classList.remove('hidden')
      this.categoryFieldWrapperTarget.classList.add('hidden')
    }
  }

  swapTransferAccounts() {
    // 互换转出/转入账户
  }
}
```

---

## Phase 3: 通用组件抽取

**预计工作量**: 2-3 小时  
**目标**: 抽取可复用的通用组件

### 3.1 月份选择器组件

当前 accounts 和 reports 页面的月份选择逻辑几乎相同，可抽取为通用 controller。

```javascript
// app/javascript/controllers/period_picker_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "display", "yearDisplay", "grid", "prevBtn", "nextBtn"]
  
  static values = {
    type: String,      // 'month' or 'year'
    value: String,     // 当前值 '2026-04' or '2026'
    pickerYear: Number // 面板显示年份
  }

  // 通用方法
  toggle() { ... }
  shiftYear(event) { ... }
  select(event) { ... }
  updateDisplay() { ... }
  renderGrid() { ... }
  
  // 暴露 change 事件供外部监听
  dispatchChange() {
    this.dispatch('change', { detail: { value: this.valueValue } })
  }
}
```

**使用方式**:
```erb
<div data-controller="period-picker" 
     data-period-picker-type-value="month"
     data-period-picker-value-value="2026-04">
  <button data-action="click->period-picker#toggle">2026年4月</button>
  <div data-period-picker-target="panel" class="hidden">
    ...
  </div>
</div>
```

### 3.2 分类筛选弹窗组件

```javascript
// app/javascript/controllers/category_filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "searchInput", "option", "countBadge", "selectAllBtn", "clearBtn", "confirmBtn"]
  
  static values = {
    selectedIds: Array,
    storageKey: String
  }

  open() { ... }
  close() { ... }
  search(event) { ... }
  selectAll() { ... }
  clearAll() { ... }
  confirm() { ... }
  
  // 暴露 change 事件
  dispatchChange() {
    this.dispatch('change', { detail: { selectedIds: this.selectedIdsValue } })
  }
}
```

---

## 实施顺序建议

### 建议顺序

1. **Phase 1: reports 页面** (优先)
   - 工作量小，可快速验证方案可行性
   - 改动范围小，风险可控

2. **Phase 3: 通用组件抽取**
   - 在 Phase 1 完成后抽取
   - 为 Phase 2 提供可复用组件

3. **Phase 2: accounts 页面**
   - 工作量大，可分批实施
   - 优先级: 
     - 2.1 账户弹窗 (独立，风险最低)
     - 2.3 视图模式切换 (独立，代码量小)
     - 2.4 交易弹窗 (独立)
     - 2.2 筛选功能 (最复杂，复用 Phase 3 的组件)

---

## 风险与注意事项

### Turbo 兼容性

- inline JS 中的 `const/let` 顶层变量会导致 Turbo 页面替换时报错（重复声明）
- 当前代码使用 IIFE 包裹，已避免此问题
- 迁移到 Stimulus 后，connect/disconnect 自动管理生命周期，更安全

### 全局函数依赖

- 当前 `onclick` 调用的全局函数需改为 `data-action`
- 检查是否有其他地方依赖这些全局函数

### 测试覆盖

- 重构后需测试:
  - 弹窗打开/关闭
  - 时间筛选切换
  - 分类筛选 localStorage
  - 局部刷新功能
  - 视图模式切换

---

## 预期收益

| 收益 | 说明 |
|------|------|
| 代码组织清晰 | JS 与 HTML 分离，符合 Stimulus 架构 |
| 自动生命周期 | Turbo 导航时自动 connect/disconnect |
| 可复用组件 | 月份选择器、分类筛选可跨页面复用 |
| 更易维护 | 单一职责，职责边界清晰 |
| 减少 inline JS | ~2000+ 行 inline JS 移入独立文件 |

---

## 进度追踪

| Phase | 任务 | 状态 | 完成日期 |
|-------|------|------|----------|
| Phase 1 | reports 时间选择器 | ✅ 完成 | 2026-04-24 |
| Phase 1 | reports 分类筛选弹窗 | ✅ 完成 | 2026-04-24 |
| Phase 1 | expense/income/comparison 筛选 | ✅ 完成 | 2026-04-24 |
| Phase 3 | period_picker_controller | ✅ 完成 | 2026-04-24 |
| Phase 3 | category_filter_controller | ✅ 完成 | 2026-04-24 |
| Phase 2.3 | view_mode_controller | ✅ 完成 | 2026-04-24 |
| Phase 2.1 | account_modal_controller | 待开始 | - |
| Phase 2.2 | account_filter_controller | 待开始 | - |
| Phase 2.4 | transaction_modal_controller | 待开始 | - |

### 已完成统计

- 删除 inline JS: ~450 行
- 新增 Stimulus controllers: 3 个
- 改动文件: 8 个

---

## 参考资料

- [Stimulus 官方文档](https://stimulus.hotwired.dev/)
- [Hotwire Turbo 最佳实践](https://turbo.hotwired.dev/handbook/introduction)
- 项目现有 controllers: `app/javascript/controllers/`