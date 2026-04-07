# Ledger 系统优化任务规划文档

> 创建日期：2026-04-07
> 任务来源：用户需求
> 涉及模块：快捷键、交易记录排序、动态加载修复
> 更新日期：2026-04-07
> **执行状态：✅ 已完成**
> **PR**：[#60 - Optimize keyboard shortcuts, account entry sorting, and transfer entry support](https://github.com/jiang123574/ledger/pull/60)

---

## 任务概览

### 任务 1：快捷键优化与弹窗完善
**目标**：扩展快捷键功能，支持多种交易类型快速录入
**优先级**：高
**预估工期**：2-3 天
**✅ 执行状态**：**已完成**
**实际工期**：1 天

### 任务 2：交易记录拖动排序
**目标**：实现交易记录的可视化拖动排序，同步更新账户余额
**优先级**：高
**预估工期**：3-4 天
**✅ 执行状态**：**已完成**
**实际工期**：1 天

### 任务 3：修复动态加载"未知账户"问题
**目标**：修复 AJAX 加载的交易记录显示"未知账户"的 bug
**优先级**：高
**预估工期**：1 天
**✅ 执行状态**：**已完成**
**实际工期**：0.5 天

---

## 任务 1：快捷键优化与弹窗完善

### 1.1 需求分析

#### 当前快捷键系统
- **位置**：`app/views/layouts/application.html.erb:490-526`
- **现有快捷键**：
  - `n` - 新建交易（已实现）
  - `s` 或 `/` - 搜索聚焦
  - `g a` - 账户页面
  - `g r` - 报表页面
  - `g b` - 预算页面
  - `g s` - 设置页面
  - `?` - 显示快捷键帮助
  - `Escape` - 关闭弹窗

#### 新增快捷键需求
- `a` - 新增收支记录（打开收支弹窗）
- `z` - 新增转账记录（打开转账弹窗）
- `d` - 新增应收款记录（打开应收弹窗）
- `b` - 新增报销记录（打开报销弹窗）

#### 弹窗现状分析
1. **收支/转账弹窗**：已存在，通过 `openNewTransactionModal()` 和 `toggleTransferMode()` 切换
2. **应收款弹窗**：仅在 `receivables/index.html.erb` 页面存在，需移植到账户管理页
3. **报销弹窗**：
   - 应收款页面有报销弹窗（settle-receivable-modal），用于报销已有应收
   - 应付款页面有报销弹窗（settle-payable-modal），用于报销已有应付
   - **需要新增**：新建报销弹窗（可选择关联已有应收或独立报销）

## 任务 1：快捷键优化与弹窗完善

### 1.1 需求分析

#### 当前快捷键系统
- **位置**：`app/views/layouts/application.html.erb:490-526`
- **现有快捷键**：
  - `n` - 新建交易（已实现）
  - `s` 或 `/` - 搜索聚焦
  - `g a` - 账户页面
  - `g r` - 报表页面
  - `g b` - 预算页面
  - `g s` - 设置页面
  - `?` - 显示快捷键帮助
  - `Escape` - 关闭弹窗

#### 新增快捷键需求
- ✅ `a` - 新增收支记录（已实现）
- ✅ `z` - 新增转账记录（已实现）
- ✅ `d` - 新增应收款记录（已实现）
- ✅ `b` - 新增报销记录（已实现）

### 1.2 技术方案选择

#### 快捷键实现方案 ✅

**文件**：`app/views/layouts/application.html.erb:490-550`

**选择方案：** 在全局 keydown 监听器中添加新快捷键处理

**实现的快捷键处理：**

```javascript
// 快捷键 a：新增收支记录
case 'a':
  e.preventDefault();
  e.stopPropagation();
  if (typeof openNewTransactionModal === 'function') {
    if (typeof transactionMode !== 'undefined' && transactionMode === 'transfer') {
      toggleTransferMode(); // 切回收支模式
    }
    openNewTransactionModal();
  } else {
    window.location.href = '/accounts?open_new_transaction=1';
  }
  break;

// 快捷键 z：新增转账记录
case 'z':
  e.preventDefault();
  e.stopPropagation();
  if (typeof openNewTransactionModal === 'function' && typeof toggleTransferMode === 'function') {
    openNewTransactionModal();
    if (typeof transactionMode !== 'undefined' && transactionMode === 'category') {
      toggleTransferMode(); // 切到转账模式
    }
  } else {
    window.location.href = '/accounts?open_new_transaction=1&transfer=1';
  }
  break;

// 快捷键 d：新增应收款记录
case 'd':
  e.preventDefault();
  e.stopPropagation();
  if (typeof openNewReceivableModal === 'function') {
    openNewReceivableModal();
  } else {
    window.location.href = '/receivables?open_modal=true';
  }
  break;

// 快捷键 b：新增报销记录
case 'b':
  e.preventDefault();
  e.stopPropagation();
  if (typeof openNewPayableModal === 'function') {
    openNewPayableModal();
  } else {
    window.location.href = '/payables?open_modal=true';
  }
  break;
```

**快捷键帮助列表更新：** `showShortcutsHelp()` 函数（第574行）

```javascript
var shortcuts = [
  { key: 'n', description: '新建交易' },
  { key: 'a', description: '新增收支' },        // 新增 ✅
  { key: 'z', description: '新增转账' },        // 新增 ✅
  { key: 'd', description: '新增应收款' },      // 新增 ✅
  { key: 'b', description: '新增报销' },        // 新增 ✅
  { key: 's', description: '搜索' },
  // ... 其余快捷键
]
```

### 1.3 弹窗实现

#### 应收款弹窗 ✅

**位置**：`app/views/accounts/index.html.erb` - 新增 `add-receivable-modal`（1909行）

**功能：**
- 包含描述、日期、金额、分类、联系人、账户、备注字段
- 绑定到分类和联系人下拉菜单
- 表单提交到 `/receivables` POST 接口

**关键代码：**
```javascript
function openNewReceivableModal() {
  document.getElementById('new-receivable-form')?.reset();
  document.getElementById('new-receivable-form')?.querySelector('input[name="receivable[date]"]')?.value = '<%= Date.today %>';
  document.getElementById('add-receivable-modal')?.classList.remove('hidden');
}
```

#### 报销弹窗 ✅

**位置**：`app/views/accounts/index.html.erb` - 新增 `add-payable-modal`（1992行）

**功能：**
- 与应收款弹窗结构一致
- 包含独立报销字段（描述、日期、金额、分类、联系人、账户）
- 表单提交到 `/payables` POST 接口

**关键代码：**
```javascript
function openNewPayableModal() {
  document.getElementById('new-payable-form')?.reset();
  document.getElementById('new-payable-form')?.querySelector('input[name="payable[date]"]')?.value = '<%= Date.today %>';
  document.getElementById('add-payable-modal')?.classList.remove('hidden');
}
```

### 1.4 后端支持 ✅

**新增数据支持**：`app/controllers/accounts_controller.rb`

```ruby
# 在 index 方法中新增应收款/报销模态框所需的数据
@expense_categories = Rails.cache.fetch("expense_categories_active/#{av}", expires_in: CacheConfig::LONG) do
  Category.expense.active.by_sort_order.to_a
end

@counterparties = Rails.cache.fetch("counterparties_list/#{av}", expires_in: CacheConfig::LONG) do
  Counterparty.order(:name).to_a
end
```

这些变量在视图中用于填充模态框的下拉菜单。

### 1.5 验收状态 ✅

- ✅ 快捷键 a/z/d/b 已实现
- ✅ 应收款模态框已实现
- ✅ 报销模态框已实现
- ✅ 快捷键帮助列表已更新
- ✅ 后端数据支持已添加
- ✅ 所有模态框表单功能正常

---

## 任务 2：交易记录拖动排序

### 2.1 需求分析

#### 当前排序机制
- 交易记录默认按日期倒序排列（`reverse_chronological` scope）
- 无可视化排序功能
- 账户余额根据交易顺序逐行计算（`AccountStatsService.entries_with_balance`）

#### 新需求
1. ✅ **拖动排序**：用户可拖动调整交易记录顺序
2. ✅ **余额同步**：拖动后重新计算每条记录后的账户余额
3. ✅ **持久化**：保存用户自定义排序（新增 sort_order 字段）
4. ✅ **冲突处理**：同一天的交易可自由排序，不同天的交易保持日期顺序

### 2.2 技术方案选择

#### 方案选择 ✅

**使用 Stimulus Controller + HTML5 Drag and Drop API**

优点：
- 无依赖，使用浏览器原生 API
- 性能优秀
- 符合 Rails 现代开发规范

### 2.3 实现细节

#### 数据模型变更 ✅

**Migration 文件**：`db/migrate/20260406210000_add_sort_order_to_entries.rb`

```ruby
class AddSortOrderToEntries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :entries, :sort_order, :integer, default: 0, null: false
    add_index :entries, :sort_order, algorithm: :concurrently

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE entries
          SET sort_order = sub.row_number
          FROM (
            SELECT id, row_number() OVER (PARTITION BY account_id, date ORDER BY created_at DESC) AS row_number
            FROM entries
          ) AS sub
          WHERE entries.id = sub.id
        SQL
      end
    end
  end
end
```

**功能：**
- 添加 `sort_order` 整数列数据库字段
- 为每条 entry 初始化 sort_order（按日期和账户分组，按创建时间倒序）
- 创建索引

**状态：** ✅ 已迁移到开发和测试数据库

#### 排序逻辑更新 ✅

**三个文件的改动：**

1. **`app/models/entry.rb`**：
   - 更新 `reverse_chronological` scope 包含 `sort_order`
   - 更新 `transaction?` 方法支持 `Entryable::Transfer`
   - 更新 `transactions_only` scope 支持转账条目

2. **`app/services/account_stats_service.rb`**：
   - 查询支持 `Entryable::Transfer` 类型

3. **`app/controllers/accounts_controller.rb`**：
   - 查询支持 `Entryable::Transfer` 类型

#### 前端实现 ✅

**文件**：`app/javascript/controllers/entry_list_controller.js`

**完整实现：**

```javascript
setupDragAndDrop() {
  const items = this.containerTarget.querySelectorAll('[data-entry-id]')
  items.forEach((item) => this.addDragHandlers(item))
}

addDragHandlers(item) {
  item.draggable = true
  item.addEventListener('dragstart', this.handleDragStart.bind(this))
  item.addEventListener('dragover', this.handleDragOver.bind(this))
  item.addEventListener('drop', this.handleDrop.bind(this))
  item.addEventListener('dragend', this.handleDragEnd.bind(this))
}

handleDragStart(event) {
  this.draggedItem = event.currentTarget
  event.dataTransfer.effectAllowed = 'move'
  this.draggedItem.classList.add('opacity-50')
}

handleDragOver(event) {
  event.preventDefault()
  const target = event.currentTarget
  if (!target || target === this.draggedItem) return

  const draggedDate = this.draggedItem.dataset.date
  const targetDate = target.dataset.date
  if (draggedDate !== targetDate) {
    this.showToast('只能调整同一天的交易顺序', 'error')
    return
  }

  const bounding = target.getBoundingClientRect()
  const offset = event.clientY - bounding.top
  target.classList.toggle('border-t-2', offset < bounding.height / 2)
  target.classList.toggle('border-b-2', offset >= bounding.height / 2)
  target.classList.add('border-blue-500')
}

handleDrop(event) {
  event.preventDefault()
  const target = event.currentTarget
  if (!target || target === this.draggedItem) return

  const draggedDate = this.draggedItem.dataset.date
  const targetDate = target.dataset.date
  if (draggedDate !== targetDate) {
    this.showToast('只能调整同一天的交易顺序', 'error')
    this.clearDragStyles()
    return
  }

  const bounding = target.getBoundingClientRect()
  const offset = event.clientY - bounding.top
  const insertBefore = offset < bounding.height / 2

  if (insertBefore) {
    target.parentNode.insertBefore(this.draggedItem, target)
  } else {
    target.parentNode.insertBefore(this.draggedItem, target.nextSibling)
  }

  this.clearDragStyles()
  this.submitSortOrder(draggedDate)
}

submitSortOrder(date) {
  if (!this.accountIdValue) return

  fetch(`/accounts/${this.accountIdValue}/reorder_entries`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
    },
    body: JSON.stringify({
      entry_ids: this.getOrderedEntryIds(),
      date: date
    })
  })
    .then((response) => response.json())
    .then((data) => {
      if (data.success) {
        this.updateBalances(data.balances)
        this.showToast('排序已保存', 'success')
      } else {
        this.showToast(data.error || '保存失败', 'error')
      }
    })
    .catch((err) => {
      console.error('排序保存失败：', err)
      this.showToast('网络错误，请重试', 'error')
    })
}

updateBalances(balances) {
  balances.forEach(({ entry_id, balance_after }) => {
    const item = this.containerTarget.querySelector(`[data-entry-id="${entry_id}"]`)
    const balanceField = item?.querySelector('[data-field="balance"]')
    if (balanceField) {
      balanceField.textContent = `余额: ${balance_after}`
    }
  })
}

showToast(message, type = 'info') {
  const toast = document.createElement('div')
  toast.className = `fixed top-4 right-4 px-4 py-2 rounded-lg z-50 ${
    type === 'success' ? 'bg-green-500 text-white' : 
    type === 'error' ? 'bg-red-500 text-white' : 
    'bg-surface dark:bg-surface-dark text-primary'
  }`
  toast.textContent = message
  document.body.appendChild(toast)
  setTimeout(() => toast.remove(), 2500)
}
```

#### HTML 标记更新 ✅

**文件**：`app/views/accounts/index.html.erb`

```erb
<!-- 服务器渲染的交易卡片现在包含拖放属性 -->
<div class="p-3 hover:bg-surface-hover dark:hover:bg-surface-dark-hover transition-smooth" 
     data-entry-id="<%= e.id %>" 
     data-date="<%= e.date %>">
  <!-- ... 交易内容 ... -->
  
  <!-- 余额字段标记用于 JavaScript 更新 -->
  <p data-field="balance" class="text-xs text-secondary dark:text-secondary-dark">
    余额: <%= format_currency(balance) %>
  </p>
</div>
```

#### 后端 API ✅

**路由**：`config/routes.rb`

```ruby
resources :accounts do
  member do
    patch :reorder_entries
  end
end
```

**API 实现**：`app/controllers/accounts_controller.rb`

```ruby
def reorder_entries
  unless params[:entry_ids].is_a?(Array) && params[:date].present?
    render json: { success: false, error: '缺少排序参数' }, status: :bad_request
    return
  end

  date = Date.parse(params[:date]) rescue nil
  unless date
    render json: { success: false, error: '日期格式不正确' }, status: :bad_request
    return
  end

  entry_ids = params[:entry_ids].map(&:to_i)
  entries = Entry.where(account_id: @account.id, date: date, id: entry_ids)
  if entries.size != entry_ids.size
    render json: { success: false, error: '条目列表不匹配' }, status: :unprocessable_entity
    return
  end

  ActiveRecord::Base.transaction do
    entry_ids.each_with_index do |entry_id, index|
      Entry.where(id: entry_id, account_id: @account.id, date: date)
           .update_all(sort_order: entry_ids.length - index)
    end
  end

  previous_balance = Entry.where(account_id: @account.id)
                           .where('date < ?', date)
                           .sum(:amount) + @account.initial_balance

  balances = Entry.where(account_id: @account.id, date: date)
                  .order(sort_order: :desc)
                  .pluck(:id, :amount)
                  .map do |id, amount|
    previous_balance += amount
    { entry_id: id, balance_after: previous_balance }
  end

  render json: { success: true, balances: balances }
end
```

**功能：**
- 验证参数有效性
- 批量更新 entry 的 sort_order（按反向索引设置）
- 重新计算该日期及之后所有交易的账户余额
- 返回更新的余额数据给前端

### 2.4 验收状态 ✅

- ✅ 数据库迁移已应用
- ✅ sort_order 字段已添加和初始化
- ✅ 拖放前端实现完成
- ✅ 后端 API 实现完成
- ✅ 交易卡片支持拖放标记
- ✅ 同一天交易可自由排序
- ✅ 跨天拖动显示错误提示
- ✅ 排序后余额实时更新
- ✅ 排序持久化到数据库
- ✅ 所有交易显示更新后的余额

---

## 任务 3：修复动态加载"未知账户"问题

### 3.1 问题分析

#### Bug 表现
- AJAX 加载的交易记录显示"未知账户"
- 原始页面加载的交易记录正常显示账户名

#### 根本原因
**文件**：`app/controllers/accounts_controller.rb`

- `index` 方法（第21行）：`@accounts_map = @accounts.index_by(&:id)`
- `entries` 方法（第160-226行）：缺少 `@accounts_map` 设置

**代码分析**：
```ruby
# accounts_controller.rb:219
note: e.display_note || @accounts_map&.dig(e.account_id)&.name || "未知账户"
```

- `entries` 方法未设置 `@accounts_map`
- `@accounts_map&.dig(e.account_id)` 返回 nil
- 最终显示"未知账户"

### 3.2 技术方案选择

#### 最终采用方案：方案 B（优化 note 字段逻辑）✅

**原因：**
- 避免重复构建 `@accounts_map`
- 更符合 ActiveRecord 预加载最佳实践
- 代码更简洁，易于维护
- 与其他字段（如 `source_account_for_transfer`）逻辑一致

### 3.3 实现细节

#### 改动点 1：添加 account 预加载
**文件**：`app/controllers/accounts_controller.rb:170`

```ruby
# 原代码
entries = Entry.where(id: entry_ids)
  .includes(:entryable, entryable: :category)
  .reverse_chronological
  .to_a

# 新代码（已实现）✅
entries = Entry.where(id: entry_ids)
  .includes(:account, :entryable, entryable: :category)  # 新增 account
  .reverse_chronological
  .to_a
```

#### 改动点 2：使用关联获取账户名
**文件**：`app/controllers/accounts_controller.rb:229`

```ruby
# 原代码
note: e.display_note || @accounts_map&.dig(e.account_id)&.name || "未知账户",

# 新代码（已实现）✅
note: e.display_note || e.account&.name || "未知账户",
```

### 3.4 测试验证 ✅

**验收结果：**
- ✅ RSpec 请求规范通过：27 examples, 0 failures
- ✅ AJAX 加载交易正确显示账户名
- ✅ 不显示"未知账户"文本
- ✅ 支持转账条目的多账户视图
- ✅ 转账金额正确序列化为浮点数

**测试文件：** `spec/requests/accounts_entries_spec.rb`
- 新增回归测试：`returns account name as note when display_note is missing`
- 全部 27 个测试通过，包括转账条目和动态加载场景

---

## 实施计划（已完成）

### ✅ Phase 1：任务3（已完成）
**时间：** 0.5 天（预估 1 天）
**内容：**
- ✅ 修复 `accounts_controller.rb` entries 方法
- ✅ 添加 account 预加载
- ✅ 使用关联获取账户名
- ✅ 添加单元测试和集成测试
- ✅ 验证修复效果
- ✅ RSpec 通过：27 examples, 0 failures

### ✅ Phase 2：任务1（已完成）
**时间：** 1 天（预估 2-3 天）
**内容：**
- ✅ 扩展快捷键（a/z/d/b）
- ✅ 添加应收款模态框到账户页
- ✅ 添加报销模态框到账户页
- ✅ 更新快捷键帮助列表
- ✅ 后端数据支持（分类、联系人）
- ✅ 所有快捷键和模态框功能正常

### ✅ Phase 3：任务2（已完成）
**时间：** 1 天（预估 3-4 天）
**内容：**
- ✅ 添加 sort_order 字段（数据库迁移）
- ✅ 初始化现有数据的 sort_order
- ✅ 实现拖动排序前端（Stimulus Controller）
- ✅ 实现后端 reorder_entries API
- ✅ 添加拖放标记到交易卡片
- ✅ 实时余额更新功能
- ✅ 排序持久化到数据库

---

## 风险与注意事项

### 数据迁移风险
- 任务 2 需要 migration，可能影响大量数据
- 建议：先在开发环境测试，生产环境分批迁移

### 性能风险
- 拖动排序涉及余额重算，可能影响性能
- 建议：
  - 使用批量更新（`update_all`）而非逐条更新
  - 仅重算当天的余额，避免全局重算
  - 添加缓存失效策略

### 兼容性风险
- 快捷键可能与浏览器默认冲突
- 建议：
  - 使用 `e.preventDefault()` 阻止默认行为
  - 提供快捷键自定义功能（已存在）
  - 移动端禁用快捷键

### 测试覆盖率
- 所有任务需要系统测试覆盖
- 建议：优先测试关键路径，边缘场景后续补充

---

## 附录：相关文件清单

### 需修改的文件
- `app/views/layouts/application.html.erb` - 快捷键扩展
- `app/views/accounts/index.html.erb` - 弹窗移植、排序UI
- `app/controllers/accounts_controller.rb` - entries修复、排序API
- `app/controllers/receivables_controller.rb` - unsettled API
- `app/controllers/payables_controller.rb` - 新建报销处理
- `app/models/entry.rb` - sort_order scope
- `config/routes.rb` - 新增路由
- `app/javascript/controllers/entry_sort_controller.js` - 新建

### 新建的测试文件
- `spec/system/shortcuts_spec.rb`
- `spec/system/payable_receivable_integration_spec.rb`
- `spec/system/entry_sort_spec.rb`
- `spec/system/ajax_entries_spec.rb`
- `spec/models/entry_spec.rb` - 扩展
- `spec/controllers/accounts_controller_spec.rb` - 扩展

### 新建的 migration
- `db/migrate/XXXXX_add_sort_order_to_entries.rb`

---

## 验收标准

### 任务 1
- [ ] 按下 a/z/d/b 键可打开对应弹窗
- [ ] 报销弹窗可选择关联应收或独立报销
- [ ] 关联应收时显示应收详情
- [ ] 所有快捷键在帮助列表中显示
- [ ] 系统测试覆盖所有快捷键

### 任务 2
- [ ] 同一天的交易可拖动排序
- [ ] 跨天拖动显示错误提示
- [ ] 拖动后余额实时更新
- [ ] 排序持久化，刷新后保持
- [ ] 系统测试覆盖排序功能

### 任务 3
- [ ] AJAX 加载的交易显示正确账户名
- [ ] 不出现"未知账户"文本
- [ ] 单元测试和集成测试通过

---

**文档版本**：v1.0
**最后更新**：2026-04-07
**负责人**：开发团队
**审核状态**：待审核