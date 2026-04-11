# frozen_string_literal: true

# 验证 transfer_id 数据完整性
# 确保所有 transfer_id 格式正确且关联数据一致
class ValidateTransferIdDataIntegrity < ActiveRecord::Migration[8.0]
  def up
    puts "=== 验证 transfer_id 数据完整性 ==="

    errors_found = false

    # 1. 验证 receivables 表的 transfer_id 格式
    errors_found |= validate_receivables_transfer_id_format

    # 2. 验证 entries 表的 transfer_id 格式
    errors_found |= validate_entries_transfer_id_format

    # 3. 验证 receivables.transfer_id 与 entries 的关联一致性
    errors_found |= validate_receivables_transfer_id_consistency

    # 4. 验证 reimbursement_transfer_ids 与 entries 的关联一致性
    errors_found |= validate_reimbursement_transfer_ids_consistency

    # 5. 验证转账配对完整性（每个 transfer_id 应有 2 条 entry）
    errors_found |= validate_transfer_pairing

    # 统计信息
    print_statistics

    if errors_found
      puts ""
      puts "❌ 验证发现错误，请检查数据完整性"
    else
      puts ""
      puts "✅ 所有验证通过，数据完整性良好"
    end

    puts "=== 验证完成 ==="
  end

  def down
    puts "验证迁移不可逆，无需回滚"
  end

  private

  def validate_receivables_transfer_id_format
    invalid_receivables = Receivable.where.not(transfer_id: nil)
                                     .where("transfer_id !~ ?", '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')

    if invalid_receivables.any?
      puts "⚠️  发现 #{invalid_receivables.count} 个 receivables 的 transfer_id 格式不正确"
      invalid_receivables.limit(10).each do |r|
        puts "  - ID: #{r.id}, transfer_id: #{r.transfer_id}"
      end
      true
    else
      puts "✅ 所有 receivables 的 transfer_id 格式正确"
      false
    end
  end

  def validate_entries_transfer_id_format
    invalid_entries = Entry.where.not(transfer_id: nil)
                            .where("transfer_id !~ ?", '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')

    if invalid_entries.any?
      puts "⚠️  发现 #{invalid_entries.count} 个 entries 的 transfer_id 格式不正确"
      invalid_entries.limit(10).each do |e|
        puts "  - ID: #{e.id}, transfer_id: #{e.transfer_id}"
      end
      true
    else
      puts "✅ 所有 entries 的 transfer_id 格式正确"
      false
    end
  end

  def validate_receivables_transfer_id_consistency
    errors_found = false

    Receivable.where.not(transfer_id: nil).find_each do |receivable|
      entries_count = Entry.where(transfer_id: receivable.transfer_id).count

      if entries_count == 0
        puts "⚠️  Receivable #{receivable.id} 的 transfer_id '#{receivable.transfer_id}' 在 entries 中不存在"
        errors_found = true
      elsif entries_count != 2
        puts "⚠️  Receivable #{receivable.id} 的 transfer_id '#{receivable.transfer_id}' 对应 #{entries_count} 条 entry（应为 2）"
        errors_found = true
      end
    end

    if !errors_found
      puts "✅ 所有 receivables 的 transfer_id 都有对应的 entry（各 2 条）"
    end

    errors_found
  end

  def validate_reimbursement_transfer_ids_consistency
    errors_found = false
    checked_count = 0

    Receivable.where.not(reimbursement_transfer_ids: [ nil, [] ]).find_each do |receivable|
      receivable.reimbursement_transfer_ids.each do |transfer_id|
        checked_count += 1
        entries_count = Entry.where(transfer_id: transfer_id.to_s).count

        if entries_count == 0
          puts "⚠️  Receivable #{receivable.id} 的 reimbursement_transfer_id '#{transfer_id}' 在 entries 中不存在"
          errors_found = true
        elsif entries_count != 2
          puts "⚠️  Receivable #{receivable.id} 的 reimbursement_transfer_id '#{transfer_id}' 对应 #{entries_count} 条 entry（应为 2）"
          errors_found = true
        end
      end
    end

    if !errors_found
      puts "✅ 所有 reimbursement_transfer_ids 都有对应的 entry（各 2 条），共检查 #{checked_count} 个 ID"
    end

    errors_found
  end

  def validate_transfer_pairing
    errors_found = false

    # 获取所有 transfer_id 及其 entry 数量
    transfer_stats = Entry.where.not(transfer_id: nil)
                           .group(:transfer_id)
                           .count

    invalid_transfers = transfer_stats.select { |_tid, count| count != 2 }

    if invalid_transfers.any?
      puts "⚠️  发现 #{invalid_transfers.size} 个 transfer_id 的配对不完整（应有 2 条 entry）"
      invalid_transfers.first(10).each do |transfer_id, count|
        puts "  - transfer_id: #{transfer_id}, entry 数量: #{count}"
      end
      errors_found = true
    else
      puts "✅ 所有 transfer_id 配对完整（每个有 2 条 entry）"
    end

    errors_found
  end

  def print_statistics
    puts ""
    puts "=== 统计信息 ==="
    puts "Receivables 总数: #{Receivable.count}"
    puts "  有 transfer_id: #{Receivable.where.not(transfer_id: nil).count}"
    puts "  有 reimbursement_transfer_ids: #{Receivable.where.not(reimbursement_transfer_ids: [ nil, [] ]).count}"

    # 统计 reimbursement_transfer_ids 总数
    total_reimbursement_ids = 0
    Receivable.where.not(reimbursement_transfer_ids: [ nil, [] ]).find_each do |r|
      total_reimbursement_ids += r.reimbursement_transfer_ids.size
    end
    puts "  reimbursement_transfer_ids 总数: #{total_reimbursement_ids}"

    puts ""
    puts "Entries 总数: #{Entry.count}"
    puts "  有 transfer_id: #{Entry.where.not(transfer_id: nil).count}"

    # 统计唯一 transfer_id 数量
    unique_transfer_ids = Entry.where.not(transfer_id: nil).distinct.pluck(:transfer_id).size
    puts "  唯一 transfer_id 数量: #{unique_transfer_ids}"
  end
end
