# frozen_string_literal: true

class MigrateAttachmentsToEntry < ActiveRecord::Migration[7.0]
  def change
    # 添加 entry_id 列到 attachments 表
    add_column :attachments, :entry_id, :bigint, null: true
    add_foreign_key :attachments, :entries, column: :entry_id, on_delete: :cascade
    add_index :attachments, :entry_id

    # 将 transaction_id 改为 optional（迁移过程中保持向后兼容）
    change_column_null :attachments, :transaction_id, true
  end
end
