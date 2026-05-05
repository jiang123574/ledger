# permit() 调用安全审计报告

**审计日期**: 2026-05-05
**审计工具**: Brakeman v8.0.4
**审计范围**: 所有 controller 的 params.permit() 调用

## 审计背景

本系统为单用户个人财务管理系统，无 User 模型和用户认证机制。所有数据属于单一用户，不存在多用户数据隔离需求。

## Brakeman 警告汇总

| 类别 | 数量 | 高风险 | 中风险 | 状态 |
|-----|------|--------|--------|------|
| Mass Assignment | 9 | 9 | 0 | 未修复（单用户风险低） |
| File Access | 4 | 0 | 4 | PR #200 部分修复 |
| SQL Injection | 4 | 0 | 4 | PR #200 已修复 |

**总警告数**: 17 → PR #200 后预计 13

## Mass Assignment 警告分析

### 1. External API Controller (Line 70)

```ruby
params.permit(:date, :type, :amount, :category, :category_id, :note, :account_id, :transaction_type)
```

**敏感字段**: `account_id`

**风险评估**: 中等
- 单用户系统，无跨用户攻击风险
- 但无效 account_id 可能导致数据不一致
- **已修复**: PR #198 添加 account 存在性验证

```ruby
params.permit(:date, :type, :amount, :category, :category_id, :note, :account_id, :transaction_type)
```

**敏感字段**: `account_id`

**风险评估**: 中等
- 单用户系统，无跨用户攻击风险
- 但无效 account_id 可能导致数据不一致
- **已修复**: PR #198 添加 account 存在性验证

### 2. Entries Controller (Line 92, 99)

```ruby
# Line 92
params.require(:entry).permit(:date, :kind, :amount, :currency, :name, :notes, :category_id, :account_id, :tag_ids => ([]))

# Line 99
params.permit(:account_id, :search, :type, :kind, :period_type, :period_value, :show_hidden, :view_mode, :page, :per_page, :category_ids => ([]))
```

**敏感字段**: `account_id`

**风险评估**: 低
- 单用户系统，所有账户属于同一用户
- Line 99 用于筛选查询，不影响数据创建
- 无需额外修复

### 3. Payables Controller (Line 115)

```ruby
params.require(:payable).permit(:date, :description, :original_amount, :source_transaction_id, :note, :category, :counterparty_id, :account_id)
```

**敏感字段**: `account_id`, `counterparty_id`

**风险评估**: 低
- 单用户系统
- 建议添加 account 存在性验证（可选）

### 4. Plans Controller (Line 94)

```ruby
params.require(:plan).permit(:name, :type, :amount, :currency, :total_amount, :installments_total, :installments_completed, :account_id, :day_of_month, :active, :last_generated, :category_id)
```

**敏感字段**: `account_id`

**风险评估**: 中等
- **已修复**: PR #199 添加 account 存在性验证

### 5. Receivables Controller (Line 135)

```ruby
params.require(:receivable).permit(:date, :description, :original_amount, :source_transaction_id, :note, :category, :counterparty_id, :account_id)
```

**敏感字段**: `account_id`, `counterparty_id`

**风险评估**: 低
- 单用户系统
- 建议添加 account 存在性验证（可选）

### 6. Recurring Controller (Line 49)

```ruby
params.require(:recurring_transaction).permit(:transaction_type, :amount, :currency, :category_id, :account_id, :note, :frequency, :next_date, :is_active)
```

**敏感字段**: `account_id`

**风险评估**: 低
- 单用户系统
- 建议添加 account 存在性验证（可选）

### 7. Transactions Controller (Line 247, 256)

```ruby
# Line 247
params.require(:transaction).permit(:date, :type, :amount, :currency, :original_amount, :category_id, :account_id, :target_account_id, :note, :link_id, :tag_ids => ([]), :files => ([]))

# Line 256
params.permit(:account_id, :search, :type, :kind, :period_type, :period_value, :show_hidden, :view_mode, :page, :per_page, :category_ids => ([]))
```

**敏感字段**: `account_id`, `target_account_id`

**风险评估**: 低
- `target_account_id` 用于转账功能，需要两个账户
- 单用户系统，无跨用户风险
- 建议添加账户存在性验证（可选）

## SQL Injection 警告分析

### 1. Settings Controller (Line 218)

```ruby
connection.execute("SET statement_timeout = '#{old_timeout}'")
```

**风险评估**: 高
- 原始代码直接拼接字符串到 SQL 命令
- `old_timeout` 来自数据库查询结果，理论上有注入风险
- **已修复**: PR #200 使用 `connection.quote(old_timeout)` 安全转义

### 2. Category Model (Line 120, 141, 162)

```ruby
# Line 120 - bulk_expense_ids_in
sanitize_sql([ "SELECT entry_id FROM entryable_transactions WHERE category_id IN (?)", ids ])

# Line 141 - bulk_income_ids_in
sanitize_sql([ "SELECT entry_id FROM entryable_transactions WHERE category_id IN (?)", ids ])

# Line 162 - bulk_transfer_ids_in
sanitize_sql([ "SELECT entry_id FROM entryable_transfers WHERE category_id IN (?)", ids ])
```

**风险评估**: 无（误报）
- 使用 Rails 标准 `sanitize_sql` 方法，参数化查询
- Brakeman 静态分析无法识别 `sanitize_sql` 的安全性
- 实际代码安全，建议配置 Brakeman 忽略此警告

## File Access 警告分析

### 1. Backup Service (Line 85)

```ruby
File.delete(BackupRecord.find_by(:id => backup_id).file_path)
```

**风险评估**: 低
- `file_path` 来自数据库模型，非用户输入
- 删除操作验证文件存在后执行

### 2. Backups Controller (Line 32)

```ruby
send_file(BackupRecord.find(params[:id]).file_path, ...)
```

**风险评估**: 中等
- 路径来自数据库记录，非直接用户输入
- 但数据库记录可能被污染，仍存在路径遍历风险
- **建议**: 添加 `realpath` 验证确保路径在 BACKUP_DIR 内

### 3. Settings Controller download_backup (Line 123)

```ruby
backup_path = BackupService::BACKUP_DIR.join(backup_name)
send_file backup_path, ...
```

**风险评估**: 中等
- 原始代码使用 `File.basename` 清理文件名
- **已修复**: PR #200 添加 `realpath` 验证确保路径在 BACKUP_DIR 内

### 4. Settings Controller restore_upload (Line 149)

```ruby
temp_path = BackupService::BACKUP_DIR.join("restore_#{Time.now.strftime('%Y%m%d_%H%M%S')}.sql")
IO.copy_stream(uploaded_file.path, temp_path)
```

**风险评估**: 低
- `temp_path` 由系统生成，不依赖用户输入
- `uploaded_file.path` 是 Rails 上传处理的临时路径
- 上传后立即执行恢复并删除临时文件
- 无路径遍历风险

## 审计结论

### 已修复项目

| 项目 | PR | 状态 |
|-----|-----|-----|
| Category 查询 SQL 安全优化 | #197 | 已合并 |
| External API account_id 验证 | #198 | 已合并 |
| Plans account_id 验证 | #199 | 已合并 |
| Settings SQL 注入 | #200 | 已合并 |
| Settings/Backups 路径遍历 | #200 | 已合并 |

### 待评估项目

以下项目在单用户场景下风险较低，可根据项目需求决定是否修复：

1. `entries_controller.rb` - account_id 验证（可选）
2. `payables_controller.rb` - account_id 验证（可选）
3. `receivables_controller.rb` - account_id 验证（可选）
4. `recurring_controller.rb` - account_id 验证（可选）
5. `transactions_controller.rb` - account_id/target_account_id 验证（可选）
6. `backups_controller.rb:32` - download 方法路径验证（建议）

### Brakeman 警告预期减少

修复合并后预期警告数：
- 当前: 17
- PR #200 后: 13 (SQL Injection 减少 1 个真实问题，File Access 减少 1 个)
- 剩余: 9 个 Mass Assignment (低风险) + 3 个 SQL Injection (误报) + 1 个 File Access (待修复)

## 建议后续行动

1. **已完成**: 合并安全修复 PR (#197-200)
2. **中优先级**: 添加 backups_controller download 方法的路径验证
3. **低优先级**: 为其他 controller 的 account_id 添加可选验证
4. **配置调整**: 配置 Brakeman 忽略 Category Model 的 3 个 sanitize_sql 误报

---

**审计人**: Claude Code
**审计完成日期**: 2026-05-05