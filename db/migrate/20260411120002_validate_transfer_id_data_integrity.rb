# frozen_string_literal: true

# 验证 transfer_id 数据完整性
# 确保所有 transfer_id 格式正确且关联数据一致
class ValidateTransferIdDataIntegrity < ActiveRecord::Migration[8.0]
  def up
    puts "=== 验证 transfer_id 数据完整性 ==="

    # 验证 receivables 表的 transfer_id 格式
    invalid_receivables = Receivable.where.not(transfer_id: nil)
                                    .where("transfer_id !~ ?", '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')

    if invalid_receivables.any?
      puts "⚠️  发现 #{invalid_receivables.count} 个 receivables 的 transfer_id 格式不正确"
      invalid_receivables.each do |r|
        puts "  - ID: #{r.id}, transfer_id: #{r.transfer_id}"
      end
    else
      puts "✅ 所有 receivables 的 transfer_id 格式正确"
    end

    # 验证 entries 表的 transfer_id 格式
    invalid_entries = Entry.where.not(transfer_id: nil)
                           .where("transfer_id !~ ?", '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')

    if invalid_entries.any?
      puts "⚠️  发现 #{invalid_entries.count} 个 entries 的 transfer_id 格式不正确"
      invalid_entries.each do |e|
        puts "  - ID: #{e.id}, transfer_id: #{e.transfer_id}"
      end
    else
      puts "✅ 所有 entries 的 transfer_id 格式正确"
    end

    # 验证 receivables 和 entries 的 transfer_id 关联一致性
    receivable_transfer_ids = Receivable.where.not(transfer_id: nil).pluck(:transfer_id).compact
    entry_transfer_ids = Entry.where.not(transfer_id: nil).pluck(:transfer_id).compact

    orphaned_receivable_ids = receivable_transfer_ids - entry_transfer_ids
    if orphaned_receivable_ids.any?
      puts "⚠️  发现 #{orphaned_receivable_ids.size} 个 receivables 的 transfer_id 在 entries 中不存在"
      orphaned_receivable_ids.first(5).each do |tid|
        puts "  - transfer_id: #{tid}"
      end
    else
      puts "✅ 所有 receivables 的 transfer_id 都有对应的 entry"
    end

    # 统计信息
    puts ""
    puts "=== 统计信息 ==="
    puts "Receivables 总数: #{Receivable.count}"
    puts "  有 transfer_id: #{Receivable.where.not(transfer_id: nil).count}"
    puts "  有 reimbursement_transfer_ids: #{Receivable.where.not(reimbursement_transfer_ids: [nil, '']).count}"
    puts ""
    puts "Entries 总数: #{Entry.count}"
    puts "  有 transfer_id: #{Entry.where.not(transfer_id: nil).count}"
    puts ""
    puts "=== 验证完成 ==="
  end

  def down
    # 验证迁移不可逆
    puts "验证迁移不可逆，无需回滚"
  end
end
