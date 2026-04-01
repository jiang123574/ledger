class AddJsonbMetadata < ActiveRecord::Migration[8.1]
  def change
    # Transaction 元数据
    add_column :transactions, :extra, :jsonb, default: {}
    add_column :transactions, :locked_attributes, :jsonb, default: {}
    add_column :transactions, :user_modified, :boolean, default: false, null: false
    
    # Account 元数据
    add_column :accounts, :extra, :jsonb, default: {}
    add_column :accounts, :locked_attributes, :jsonb, default: {}
    
    # Category 元数据
    add_column :categories, :extra, :jsonb, default: {}
    
    # JSONB 索引 - 学习 Sure 的 GIN 索引策略
    add_index :transactions, :extra, using: :gin, name: 'idx_trans_extra_gin'
    add_index :transactions, :locked_attributes, using: :gin, name: 'idx_trans_locked_gin'
    add_index :accounts, :extra, using: :gin, name: 'idx_accounts_extra_gin'
    add_index :accounts, :locked_attributes, using: :gin, name: 'idx_accounts_locked_gin'
    
    # 部分索引
    add_index :transactions, :user_modified, 
              name: 'idx_trans_user_modified', 
              where: "user_modified = true"
  end
end