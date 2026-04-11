# frozen_string_literal: true

# 将整数格式的 transfer_id 转换为 UUID 格式
# 解决数据格式不一致问题
class ConvertTransferIdToUuidFormat < ActiveRecord::Migration[8.0]
  def up
    puts "=== 开始转换 transfer_id 为 UUID 格式 ==="

    # 处理 receivables 表
    convert_receivables_transfer_ids

    # 处理 entries 表
    convert_entries_transfer_ids

    puts "=== 转换完成 ==="
  end

  def down
    puts "此迁移不可逆，无法回滚"
  end

  private

  def convert_receivables_transfer_ids
    puts "处理 receivables 表..."

    # 查找所有整数格式的 transfer_id
    receivables_with_integer_transfer = Receivable.where(
      "transfer_id ~ ?", '^\d+$'
    )

    puts "  发现 #{receivables_with_integer_transfer.count} 条整数格式记录"

    receivables_with_integer_transfer.find_each do |receivable|
      # 生成新的 UUID
      new_transfer_id = SecureRandom.uuid

      # 更新记录
      receivable.update_column(:transfer_id, new_transfer_id)

      # 同时更新 reimbursement_transfer_ids 中的整数
      if receivable.reimbursement_transfer_ids.present?
        new_reimbursement_ids = receivable.reimbursement_transfer_ids.map do |id|
          id.to_s.match?(/^\d+$/) ? SecureRandom.uuid : id
        end
        receivable.update_column(:reimbursement_transfer_ids, new_reimbursement_ids)
      end
    end

    puts "  receivables 表转换完成"
  end

  def convert_entries_transfer_ids
    puts "处理 entries 表..."

    # 查找所有整数格式的 transfer_id
    entries_with_integer_transfer = Entry.where(
      "transfer_id ~ ?", '^\d+$'
    )

    puts "  发现 #{entries_with_integer_transfer.count} 条整数格式记录"

    # 按 transfer_id 分组，确保相同的整数生成相同的 UUID
    transfer_id_mapping = {}

    entries_with_integer_transfer.find_each do |entry|
      old_transfer_id = entry.transfer_id

      # 如果这个整数已经映射过，使用相同的 UUID
      unless transfer_id_mapping.key?(old_transfer_id)
        transfer_id_mapping[old_transfer_id] = SecureRandom.uuid
      end

      new_transfer_id = transfer_id_mapping[old_transfer_id]
      entry.update_column(:transfer_id, new_transfer_id)
    end

    puts "  entries 表转换完成"
    puts "  共生成 #{transfer_id_mapping.size} 个唯一 UUID"
  end
end
