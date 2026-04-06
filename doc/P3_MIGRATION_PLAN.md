# P3: Transaction -> Entry 迁移计划

## 目标
将所有Transaction相关的数据和关联迁移到Entry体系，最终移除Transaction模型。

## 阶段1: 数据库Schema更新
需要对Entry和相关表进行以下修改：

### 1.1 Entry表扩展
- 添加老的Transaction.id映射（用于迁移后旧系统兼容性）
- 添加迁移标记

### 1.2 Entryable::Transaction表更新  
- 添加transaction_id外键（迁移中间状态）
- 添加attachment_count counter cache

### 1.3 Attachment表重构
- 修改foreign key: transaction_id -> entry_id
- 添加polymorphic_type支持多种类型entry

### 1.4 Receivable/Payable更新
- 修改source_transaction -> source_entry关联
- 更新字段映射

## 阶段2: 代码关联设置
- Entry/Entryable::Transaction添加attachment关联
- Receivable/Payable更新关联到Entry
- 创建兼容层（Transaction模型变为Entry的别名）

## 阶段3: 数据迁移脚本
编写rake task:
- rails migrate_to_entry:all_transactions
- rails migrate_to_entry:verify
- rails migrate_to_entry:cleanup

## 阶段4: 代码清理
- 移除Transaction模型（完全替换为Entry）
- 更新所有控制器和服务
- 移除transaction相关的views

## 关键考虑点
- Attachment关联需要指向Entry还是Entryable::Transaction?
  -> 推荐指向Entry，但需要支持多类型polymorphic
- Transaction/Receivable/Payable之间的关系如何处理?
  -> 创建中间关系表或在Entry中存储关联info
- 迁移期间如何保持系统正常运行?
  -> 创建兼容层，支持旧路径和新路径并存

## 当前状态
- Entry模型已完全实现
- 大部分代码已改用Entry
- Transaction模型仍然存在但不是主流

## 实施步骤
1. ✅ P3-1: 添加必要的Schema迁移
   - ✅ Attachments 表迁移 (entry_id, 索引, transaction_id nullable)
   - ✅ Receivables/Payables 表迁移 (source_entry_id, 索引)
   - ✅ Entryable::Transaction 增强 (source_transaction_id, 索引)
   
2. ✅ P3-2: 更新Entry/Entryable关联
   - ✅ Entry 模型: has_many :attachments, receivables_as_source, payables_as_source
   - ✅ Attachment 模型: 双向支持 (entry_id + transaction_id)
   - ✅ Receivable 模型: source_entry, source_transaction 并存
   - ✅ Payable 模型: source_entry, source_transaction 并存
   - ✅ Entryable::Transaction: source_transaction 追踪
   
3. ✅ P3-3: 编写数据迁移脚本
   - ✅ rake migrate_to_entry:attachments - 迁移附件关联
   - ✅ rake migrate_to_entry:verify_attachments - 验证附件迁移
   - ✅ rake migrate_to_entry:receivables_payables - 迁移应收/应付
   - ✅ rake migrate_to_entry:verify_receivables_payables - 验证应收/应付迁移
   - ✅ rake migrate_to_entry:verify_all - 综合验证所有迁移状态
   
4. ✅ P3-4: 测试迁移脚本
   - ✅ Schema 迁移成功应用
   - ✅ 所有 rake 任务正常运行
   - ✅ 数据验证通过
   - ✅ Entry 数据验证通过 (29,678 Entry)
   
5. 📋 P3-5: 代码清理和兼容层移除 (待future PR)
   - 待做：渐进式废弃 Transaction 查询
   - 待做：移除 transaction_id 引用
   - 待做：最终清理旧表

## 当前状态 (2026-04-06 更新)
- ✅ Schema 完全就绪: Attachment, Receivable, Payable 都支持 Entry 关联
- ✅ 迁移基础设施: 仓库中存在4个schema迁移，7个rake任务，完整的验证体系
- ✅ 模型系统: Entry 是中心，所有模型都支持新旧关系并存（向后兼容）
- ✅ 测试就绪: 所有迁移任务已激活并可用

系统数据现状:
- 29,678 Entry (全为 Entryable::Transaction)
- 0 Attachment
- 6 Receivable (无legacy transaction引用)
- 1 Payable (无legacy transaction引用)

## 迁移完成度
- Schema 迁移: ✅ 100%
- 模型更新: ✅ 100%
- 迁移脚本: ✅ 100%
- 数据迁移: ✓ 无需迁移 (系统已是纯Entry)
- 代码清理: ⏳ 待future PR
