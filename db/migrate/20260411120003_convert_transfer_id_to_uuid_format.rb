# frozen_string_literal: true

# 将整数格式的 transfer_id 转换为 UUID 格式
# 解决数据格式不一致问题
#
# 关键修复：确保 entries 和 receivables 使用相同的映射，
# 避免转账记录关联断裂
class ConvertTransferIdToUuidFormat < ActiveRecord::Migration[8.0]
  def up
    puts "=== 开始转换 transfer_id 为 UUID 格式 ==="

    # Step 1: 收集所有整数 transfer_id 并建立统一映射
    @transfer_id_mapping = build_transfer_id_mapping

    # Step 2: 使用映射更新 entries 表
    update_entries_with_mapping

    # Step 3: 使用映射更新 receivables 表
    update_receivables_with_mapping

    puts "=== 转换完成 ==="
  end

  def down
    puts "此迁移不可逆，无法回滚"
  end

  private

  def build_transfer_id_mapping
    puts "Step 1: 收集所有整数 transfer_id..."

    all_integer_ids = Set.new

    # 收集 entries 表中的整数 transfer_id
    entries_integer_ids = Entry.where("transfer_id ~ ?", '^\d+$').pluck(:transfer_id).uniq
    all_integer_ids.merge(entries_integer_ids)
    puts "  entries 表: #{entries_integer_ids.size} 个唯一整数"

    # 收集 receivables.transfer_id 中的整数
    receivables_integer_ids = Receivable.where("transfer_id ~ ?", '^\d+$').pluck(:transfer_id).uniq
    all_integer_ids.merge(receivables_integer_ids)
    puts "  receivables.transfer_id: #{receivables_integer_ids.size} 个唯一整数"

    # 收集 receivables.reimbursement_transfer_ids 中的整数
    reimbursement_integer_ids = Set.new
    Receivable.where.not(reimbursement_transfer_ids: [ nil, [] ]).find_each do |receivable|
      receivable.reimbursement_transfer_ids.each do |id|
        id_str = id.to_s
        reimbursement_integer_ids.add(id_str) if id_str.match?(/^\d+$/)
      end
    end
    all_integer_ids.merge(reimbursement_integer_ids.to_a)
    puts "  receivables.reimbursement_transfer_ids: #{reimbursement_integer_ids.size} 个唯一整数"

    puts "  总计: #{all_integer_ids.size} 个唯一整数 transfer_id"

    # 建立映射
    mapping = {}
    all_integer_ids.each do |old_id|
      mapping[old_id] = SecureRandom.uuid
    end

    puts "  映射建立完成"
    mapping
  end

  def update_entries_with_mapping
    puts "Step 2: 更新 entries 表..."

    count = 0
    Entry.where("transfer_id ~ ?", '^\d+$').find_each do |entry|
      new_uuid = @transfer_id_mapping[entry.transfer_id]
      if new_uuid
        entry.update_column(:transfer_id, new_uuid)
        count += 1
      end
    end

    puts "  更新了 #{count} 条记录"
  end

  def update_receivables_with_mapping
    puts "Step 3: 更新 receivables 表..."

    count_transfer_id = 0
    count_reimbursement = 0

    Receivable.find_each do |receivable|
      updated = false

      # 更新 transfer_id（如果是整数）
      if receivable.transfer_id.present? && receivable.transfer_id.match?(/^\d+$/)
        new_uuid = @transfer_id_mapping[receivable.transfer_id]
        if new_uuid
          receivable.update_column(:transfer_id, new_uuid)
          count_transfer_id += 1
          updated = true
        end
      end

      # 更新 reimbursement_transfer_ids 中的整数
      if receivable.reimbursement_transfer_ids.present?
        new_ids = receivable.reimbursement_transfer_ids.map do |id|
          id_str = id.to_s
          if id_str.match?(/^\d+$/)
            new_uuid = @transfer_id_mapping[id_str]
            if new_uuid
              count_reimbursement += 1 unless updated
              new_uuid
            else
              id
            end
          else
            id
          end
        end

        # 只有确实有变化才更新
        if new_ids != receivable.reimbursement_transfer_ids
          receivable.update_column(:reimbursement_transfer_ids, new_ids)
          updated = true
        end
      end
    end

    puts "  transfer_id 更新: #{count_transfer_id} 条"
    puts "  reimbursement_transfer_ids 更新: #{count_reimbursement} 个 ID"
  end
end
