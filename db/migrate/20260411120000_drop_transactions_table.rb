# frozen_string_literal: true

# 删除 transactions 表和 transaction_tags 表
# 这是 Transaction 模型完全移除的最后一步
class DropTransactionsTable < ActiveRecord::Migration[8.0]
  def up
    # 移除外键约束
    remove_foreign_key :attachments, :transactions if foreign_key_exists?(:attachments, :transactions)
    remove_foreign_key :transaction_tags, :transactions if foreign_key_exists?(:transaction_tags, :transactions)
    remove_foreign_key :payables, :transactions if foreign_key_exists?(:payables, :transactions)
    remove_foreign_key :receivables, :transactions if foreign_key_exists?(:receivables, :transactions)

    # 删除 transaction_tags 表
    drop_table :transaction_tags if table_exists?(:transaction_tags)

    # 删除 transactions 表
    drop_table :transactions if table_exists?(:transactions)

    puts "✅ Dropped transaction_tags and transactions tables"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot recreate transactions table - data migration required"
  end
end
