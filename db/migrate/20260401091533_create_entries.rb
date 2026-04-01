# Entry 统一模型设计
# 学习自 Sure 项目: https://github.com/we-promise/sure
#
# 设计理念：
# 1. Entry 是所有财务记录的统一入口
# 2. 使用 delegated_type 支持多种类型（Transaction, Valuation, Trade 等）
# 3. 统一的查询接口，减少 JOIN
# 4. JSONB 字段存储灵活元数据
#
# 架构：
# Entry (主表)
#   - entryable_type: "Transaction", "Valuation", "Trade"
#   - entryable_id: 关联到具体类型表
#
# Entryable::Transaction (具体交易)
#   - category_id
#   - merchant_id
#   - tags
#   - 具体交易逻辑
#
# Entryable::Valuation (估值)
#   - 估值逻辑
#
# Entryable::Trade (交易)
#   - 证券交易逻辑

class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    # 1. 创建 entries 表（使用 integer ID 兼容现有系统）
    create_table :entries do |t|
      # 关联（使用 integer 兼容现有 accounts 表）
      t.integer :account_id, null: false
      t.string :entryable_type, null: false
      t.integer :entryable_id, null: false
      t.integer :transfer_id
      t.integer :import_id
      t.integer :parent_entry_id
      
      # 基础字段
      t.decimal :amount, precision: 19, scale: 4, null: false
      t.string :currency, null: false, default: 'CNY'
      t.date :date, null: false
      t.string :name, null: false
      t.text :notes
      
      # 元数据
      t.jsonb :extra, default: {}
      t.jsonb :locked_attributes, default: {}
      t.boolean :user_modified, default: false, null: false
      t.boolean :import_locked, default: false, null: false
      t.boolean :excluded, default: false, null: false
      
      # 外部同步
      t.string :external_id
      t.string :source
      
      # 审计
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
    
    # 2. 添加索引
    # 主键索引
    add_index :entries, :id, unique: true
    
    # 复合索引 - 学习 Sure 的索引策略
    add_index :entries, [:account_id, :date], name: 'idx_entries_account_date'
    add_index :entries, [:account_id, :date, :entryable_type], name: 'idx_entries_account_date_type'
    add_index :entries, [:date, :entryable_type], name: 'idx_entries_date_type'
    
    # Entryable 索引
    add_index :entries, [:entryable_type, :entryable_id], name: 'idx_entries_entryable'
    
    # 转账索引
    add_index :entries, :transfer_id, name: 'idx_entries_transfer'
    
    # 导入索引
    add_index :entries, :import_id, name: 'idx_entries_import'
    
    # 分层交易索引
    add_index :entries, :parent_entry_id, name: 'idx_entries_parent'
    
    # 外部 ID 唯一索引
    add_index :entries, [:account_id, :source, :external_id], 
              name: 'idx_entries_external_unique',
              unique: true,
              where: "external_id IS NOT NULL AND source IS NOT NULL"
    
    # JSONB 索引
    add_index :entries, :extra, using: :gin, name: 'idx_entries_extra_gin'
    add_index :entries, :locked_attributes, using: :gin, name: 'idx_entries_locked_gin'
    
    # 部分索引
    add_index :entries, :user_modified, 
              name: 'idx_entries_user_modified',
              where: "user_modified = true"
    
    add_index :entries, :excluded,
              name: 'idx_entries_excluded',
              where: "excluded = true"
    
    add_index :entries, :import_locked,
              name: 'idx_entries_import_locked',
              where: "import_locked = true"
    
    # 名称搜索索引
    add_index :entries, "lower(name)", name: 'idx_entries_name_lower'
    
    # 3. 创建 entryable_transactions 表
    create_table :entryable_transactions do |t|
      t.integer :category_id
      t.integer :merchant_id
      t.string :kind
      t.jsonb :tags, default: []
      t.jsonb :extra, default: {}
      t.jsonb :locked_attributes, default: {}
      
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
    
    add_index :entryable_transactions, :category_id, name: 'idx_trans_category'
    add_index :entryable_transactions, :merchant_id, name: 'idx_trans_merchant'
    add_index :entryable_transactions, :tags, using: :gin, name: 'idx_trans_tags_gin'
    
    # 4. 创建 entryable_valuations 表
    create_table :entryable_valuations do |t|
      t.jsonb :extra, default: {}
      t.jsonb :locked_attributes, default: {}
      
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
    
    # 5. 创建 entryable_trades 表（证券交易）
    create_table :entryable_trades do |t|
      t.integer :security_id
      t.decimal :qty, precision: 19, scale: 4
      t.decimal :price, precision: 19, scale: 4
      t.jsonb :extra, default: {}
      t.jsonb :locked_attributes, default: {}
      
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
    
    add_index :entryable_trades, :security_id, name: 'idx_trades_security'
    
    # 6. 添加外键约束（使用 integer 兼容现有系统）
    add_foreign_key :entries, :accounts, column: :account_id, on_delete: :cascade
    add_foreign_key :entries, :entries, column: :parent_entry_id, on_delete: :nullify
    add_foreign_key :entryable_transactions, :categories, column: :category_id, on_delete: :nullify
  end
end