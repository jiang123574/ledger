# frozen_string_literal: true

class EnhanceEntryableTransactionForMigration < ActiveRecord::Migration[7.0]
  def change
    # 添加 source_transaction_id 到 entryable_transactions 表
    # 用于在数据迁移期间追踪原始 Transaction
    add_column :entryable_transactions, :source_transaction_id, :bigint, null: true
    add_index :entryable_transactions, :source_transaction_id
  end
end
