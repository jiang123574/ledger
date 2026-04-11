# frozen_string_literal: true

# 将 transfer_id 从 integer 改为 string，支持 UUID 格式
# 避免 SecureRandom.random_number(2**31) 的碰撞风险
class ChangeTransferIdToString < ActiveRecord::Migration[8.0]
  def up
    # 先删除索引
    remove_index :entries, :transfer_id, if_exists: true, name: "idx_entries_transfer"
    remove_index :receivables, :transfer_id, if_exists: true

    # 修改字段类型
    change_column :entries, :transfer_id, :string
    change_column :receivables, :transfer_id, :string

    # 重新创建索引
    add_index :entries, :transfer_id, name: "idx_entries_transfer"
    add_index :receivables, :transfer_id
  end

  def down
    # 先删除索引
    remove_index :entries, :transfer_id, if_exists: true, name: "idx_entries_transfer"
    remove_index :receivables, :transfer_id, if_exists: true

    # 修改字段类型回 integer
    change_column :entries, :transfer_id, :integer, using: "transfer_id::integer"
    change_column :receivables, :transfer_id, :integer, using: "transfer_id::integer"

    # 重新创建索引
    add_index :entries, :transfer_id, name: "idx_entries_transfer"
    add_index :receivables, :transfer_id
  end
end
