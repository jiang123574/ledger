# frozen_string_literal: true

# 从 payables 和 entryable_transactions 表移除 source_transaction_id 字段
# 这是 Transaction 模型完全移除的最后一步
class RemoveSourceTransactionIdFromTables < ActiveRecord::Migration[8.0]
  def up
    # 从 entryable_transactions 表移除
    if column_exists?(:entryable_transactions, :source_transaction_id)
      remove_column :entryable_transactions, :source_transaction_id, :bigint
      puts "✅ Removed source_transaction_id from entryable_transactions"
    end

    # 从 payables 表移除
    if column_exists?(:payables, :source_transaction_id)
      remove_column :payables, :source_transaction_id, :integer
      puts "✅ Removed source_transaction_id from payables"
    end
  end

  def down
    # 回滚：重新添加字段
    unless column_exists?(:entryable_transactions, :source_transaction_id)
      add_column :entryable_transactions, :source_transaction_id, :bigint
      add_index :entryable_transactions, :source_transaction_id
      puts "✅ Re-added source_transaction_id to entryable_transactions"
    end

    unless column_exists?(:payables, :source_transaction_id)
      add_column :payables, :source_transaction_id, :integer
      add_index :payables, :source_transaction_id
      puts "✅ Re-added source_transaction_id to payables"
    end
  end
end
