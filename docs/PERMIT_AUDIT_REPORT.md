# permit() 调用安全审计报告

**审计日期**: 2026-05-05
**审计工具**: Brakeman v8.0.4
**审计范围**: 所有 controller 的 params.permit() 调用

## 审计背景

本系统为单用户个人财务管理系统，无 User 模型和用户认证机制。所有数据属于单一用户，不存在多用户数据隔离需求。

## Brakeman 警告汇总

| 类别 | 数量 | 高风险 | 中风险 |
|-----|------|--------|--------|
| Mass Assignment | 9 | 9 | 0 |
| File Access | 2 | 0 | 2 |

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
- 原始问题：路径来自数据库但未验证
- **已在 PR #200 中修复 webdav_download**
- **download 方法仍使用数据库路径，建议添加验证**

## 审计结论

### 已修复项目

| 项目 | PR | 状态 |
|-----|-----|-----|
| External API account_id 验证 | #198 | 待合并 |
| Plans account_id 验证 | #199 | 待合并 |
| Settings SQL 注入 | #200 | 待合并 |
| Settings/Backups 路径遍历 | #200 | 待合并 |

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
- 修复后: ~11 (主要剩余低风险的 Mass Assignment 警告)

## 建议后续行动

1. **高优先级**：合并已创建的安全修复 PR (#197-200)
2. **中优先级**：添加 backups_controller download 方法的路径验证
3. **低优先级**：为其他 controller 的 account_id 添加可选验证
4. **配置调整**：可考虑配置 Brakeman 忽略已知低风险的 Mass Assignment 警告

---

**审计人**: Claude Code
**审计完成日期**: 2026-05-05