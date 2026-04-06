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
2. ✅ P3-2: 更新Entry/Entryable关联
3. ✅ P3-3: 编写数据迁移脚本  
4. ✅ P3-4: 测试迁移脚本
5. ✅ P3-5: 代码清理和兼容层移除
