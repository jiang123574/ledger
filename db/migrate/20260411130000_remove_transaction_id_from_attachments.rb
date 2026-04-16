# frozen_string_literal: true

# 从 attachments 表移除 transaction_id 字段
# 这是 Transaction 模型完全移除的最后一步
class RemoveTransactionIdFromAttachments < ActiveRecord::Migration[8.0]
  def up
    # 移除索引
    remove_index :attachments, :transaction_id if index_exists?(:attachments, :transaction_id)
    remove_index :attachments, [ :transaction_id, :file_type ] if index_exists?(:attachments, [ :transaction_id, :file_type ])

    # 移除外键约束（如果存在）
    remove_foreign_key :attachments, :transactions if foreign_key_exists?(:attachments, :transactions)

    # 移除字段
    remove_column :attachments, :transaction_id, :integer if column_exists?(:attachments, :transaction_id)

    puts "✅ Removed transaction_id from attachments table"
  end

  def down
    # 回滚：重新添加字段
    unless column_exists?(:attachments, :transaction_id)
      add_column :attachments, :transaction_id, :integer
      add_index :attachments, :transaction_id
      add_index :attachments, [ :transaction_id, :file_type ]
      puts "✅ Re-added transaction_id to attachments table"
    end
  end
end
