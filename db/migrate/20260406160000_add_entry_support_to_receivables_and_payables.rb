# frozen_string_literal: true

class AddEntrySupportToReceivablesAndPayables < ActiveRecord::Migration[7.0]
  def change
    # 添加 source_entry_id 到 receivables 表
    add_column :receivables, :source_entry_id, :bigint, null: true
    add_foreign_key :receivables, :entries, column: :source_entry_id, on_delete: :nullify
    add_index :receivables, :source_entry_id

    # 添加 source_entry_id 到 payables 表
    add_column :payables, :source_entry_id, :bigint, null: true
    add_foreign_key :payables, :entries, column: :source_entry_id, on_delete: :nullify
    add_index :payables, :source_entry_id
  end
end
