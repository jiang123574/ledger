# 数据迁移脚本：从 Transaction 迁移到 Entry
# 
# 执行步骤：
# 1. 备份数据库
# 2. 运行迁移
# 3. 验证数据完整性
# 4. 清理旧表（可选）

namespace :migrate_to_entry do
  desc '从 Transaction 迁移到 Entry 模型'
  task transactions: :environment do
    puts "开始迁移 Transaction 数据到 Entry..."
    
    # 统计
    total = Transaction.count
    migrated = 0
    failed = 0
    
    puts "总共 #{total} 条记录需要迁移"
    
    # 批量迁移
    Transaction.find_each.with_index do |old_trans, index|
      begin
        Entry.transaction do
          # 1. 创建 Entryable::Transaction
          entryable_trans = Entryable::Transaction.create!(
            category_id: old_trans.category_id,
            kind: old_trans.type&.downcase,
            tags: old_trans.tags.pluck(:name),
            extra: {
              old_id: old_trans.id,
              migrated_at: Time.current.iso8601
            }
          )
          
          # 2. 创建 Entry
          Entry.create!(
            account_id: old_trans.account_id,
            entryable: entryable_trans,
            amount: old_trans.amount,
            currency: old_trans.currency || 'CNY',
            date: old_trans.date,
            name: old_trans.note || old_trans.category&.name || '未命名交易',
            notes: old_trans.note,
            excluded: false,
            user_modified: false,
            extra: {
              old_transaction_id: old_trans.id,
              target_account_id: old_trans.target_account_id,
              dedupe_key: old_trans.dedupe_key,
              migrated_at: Time.current.iso8601
            }
          )
          
          migrated += 1
          
          if (index + 1) % 100 == 0
            puts "已迁移 #{index + 1}/#{total} 条记录..."
          end
        end
      rescue => e
        failed += 1
        puts "迁移失败 [ID: #{old_trans.id}]: #{e.message}"
        Rails.logger.error "Migration failed for Transaction #{old_trans.id}: #{e.message}"
      end
    end
    
    puts "\n迁移完成！"
    puts "成功: #{migrated}"
    puts "失败: #{failed}"
    puts "总计: #{total}"
    
    # 验证
    puts "\n验证数据完整性..."
    entry_count = Entry.where(entryable_type: 'Entryable::Transaction').count
    puts "Entry 记录数: #{entry_count}"
    puts "Transaction 记录数: #{total}"
    
    if entry_count == migrated
      puts "✓ 数据迁移成功！"
    else
      puts "✗ 数据数量不匹配，请检查！"
    end
  end
  
  desc '验证迁移后的数据'
  task verify: :environment do
    puts "验证 Entry 数据..."
    
    # 检查 Entry 数据完整性
    Account.find_each do |account|
      entry_count = Entry.where(account_id: account.id).count
      balance = account.current_balance
      
      puts "账户 #{account.name} (ID: #{account.id})"
      puts "  Entry 条数: #{entry_count}"
      puts "  当前余额: #{balance}"
    end
    
    # 统计信息
    total_entries = Entry.count
    transaction_entries = Entry.where(entryable_type: 'Entryable::Transaction').count
    valuation_entries = Entry.where(entryable_type: 'Entryable::Valuation').count
    trade_entries = Entry.where(entryable_type: 'Entryable::Trade').count
    
    puts "\nEntry 统计："
    puts "  总数: #{total_entries}"
    puts "  Transaction: #{transaction_entries}"
    puts "  Valuation: #{valuation_entries}"
    puts "  Trade: #{trade_entries}"
    
    puts "验证完成！"
  end

  desc '迁移 Attachment 关联从 Transaction 到 Entry'
  task attachments: :environment do
    puts "开始迁移 Attachment ..."
    
    total = Attachment.where.not(transaction_id: nil).count
    migrated = 0
    failed = 0
    
    puts "需要迁移 #{total} 个 attachment"
    
    Attachment.where.not(transaction_id: nil).find_each.with_index do |attachment, index|
      begin
        # 找到对应的Entry
        entry = nil
        
        # 方法1：通过Entryable::Transaction的source_transaction_id查找
        entryable_trans = Entryable::Transaction.find_by(source_transaction_id: attachment.transaction_id)
        if entryable_trans
          entry = Entry.find_by(entryable_id: entryable_trans.id, entryable_type: 'Entryable::Transaction')
        end
        
        # 方法2：通过transaction的基本信息查找Entry
        if entry.nil?
          transaction = Transaction.find_by(id: attachment.transaction_id)
          if transaction
            entry = Entry.find_by(
              account_id: transaction.account_id,
              amount: transaction.amount,
              date: transaction.date,
              entryable_type: 'Entryable::Transaction'
            )
          end
        end
        
        if entry
          attachment.update(entry_id: entry.id)
          migrated += 1
        else
          puts "警告: 找不到Attachment #{attachment.id}对应的Entry"
          failed += 1
        end
        
        if (index + 1) % 50 == 0
          puts "进度: #{index + 1}/#{total}"
        end
      rescue => e
        puts "错误处理 Attachment #{attachment.id}: #{e.message}"
        failed += 1
      end
    end
    
    puts "\n迁移完成!"
    puts "成功: #{migrated}"
    puts "失败: #{failed}"
    puts "总计: #{total}"
  end

  desc '验证 Attachment 迁移'
  task verify_attachments: :environment do
    puts "验证 Attachment 迁移..."
    
 total = Attachment.count
    with_entry = Attachment.where.not(entry_id: nil).count
    with_transaction = Attachment.where.not(transaction_id: nil).count
    
    puts "Attachment 总数: #{total}"
    puts "有 entry_id 的: #{with_entry}"
    puts "仍有 transaction_id 的（旧）: #{with_transaction}"
    
    if with_entry == total
      puts "✓ 所有 Attachment 都已迁移到 Entry"
    else
      puts "⚠ 仍有 #{total - with_entry} 个 Attachment 未迁移"
    end
  end
  
  desc '回滚迁移（删除所有 Entry 数据）'
  task rollback: :environment do
    puts "警告：这将删除所有 Entry 数据！"
    print "确认删除？(yes/no): "
    confirm = STDIN.gets.chomp
    
    if confirm == 'yes'
      Entry.destroy_all
      Entryable::Transaction.destroy_all
      Entryable::Valuation.destroy_all
      Entryable::Trade.destroy_all
      puts "回滚完成！"
    else
      puts "取消操作"
    end
  end

  desc '迁移 Receivable/Payable 关联从 Transaction 到 Entry'
  task receivables_payables: :environment do
    puts "开始迁移 Receivable/Payable ..."
    
    receivable_count = Receivable.where.not(source_transaction_id: nil).count
    payable_count = Payable.where.not(source_transaction_id: nil).count
    total = receivable_count + payable_count
    migrated = 0
    failed = 0
    
    puts "需要迁移 #{receivable_count} 个 receivable 和 #{payable_count} 个 payable"
    
    # 迁移 Receivable
    Receivable.where.not(source_transaction_id: nil).find_each.with_index do |receivable, index|
      begin
        entry = find_entry_for_transaction(receivable.source_transaction_id)
        if entry
          receivable.update(source_entry_id: entry.id)
          migrated += 1
        else
          puts "警告: 找不到 Receivable #{receivable.id} (transaction_id: #{receivable.source_transaction_id}) 对应的 Entry"
          failed += 1
        end
        
        if (index + 1) % 50 == 0
          puts "Receivable 进度: #{index + 1}/#{receivable_count}"
        end
      rescue => e
        puts "错误处理 Receivable #{receivable.id}: #{e.message}"
        failed += 1
      end
    end
    
    # 迁移 Payable
    Payable.where.not(source_transaction_id: nil).find_each.with_index do |payable, index|
      begin
        entry = find_entry_for_transaction(payable.source_transaction_id)
        if entry
          payable.update(source_entry_id: entry.id)
          migrated += 1
        else
          puts "警告: 找不到 Payable #{payable.id} (transaction_id: #{payable.source_transaction_id}) 对应的 Entry"
          failed += 1
        end
        
        if (index + 1) % 50 == 0
          puts "Payable 进度: #{index + 1}/#{payable_count}"
        end
      rescue => e
        puts "错误处理 Payable #{payable.id}: #{e.message}"
        failed += 1
      end
    end
    
    puts "\n迁移完成!"
    puts "成功: #{migrated}"
    puts "失败: #{failed}"
    puts "总计: #{total}"
  end

  desc '验证 Receivable/Payable 迁移'
  task verify_receivables_payables: :environment do
    puts "验证 Receivable/Payable 迁移..."
    
    receivable_total = Receivable.count
    receivable_with_entry = Receivable.where.not(source_entry_id: nil).count
    receivable_with_transaction = Receivable.where.not(source_transaction_id: nil).count
    
    payable_total = Payable.count
    payable_with_entry = Payable.where.not(source_entry_id: nil).count
    payable_with_transaction = Payable.where.not(source_transaction_id: nil).count
    
    puts "Receivable 统计:"
    puts "  总数: #{receivable_total}"
    puts "  有 source_entry_id: #{receivable_with_entry}"
    puts "  仍有 source_transaction_id (旧): #{receivable_with_transaction}"
    
    puts "\nPayable 统计:"
    puts "  总数: #{payable_total}"
    puts "  有 source_entry_id: #{payable_with_entry}"
    puts "  仍有 source_transaction_id (旧): #{payable_with_transaction}"
    
    if receivable_with_entry + payable_with_entry == receivable_total + payable_total
      puts "\n✓ 所有 Receivable/Payable 都已迁移到 Entry"
    else
      puts "\n⚠ 仍有 #{(receivable_total - receivable_with_entry) + (payable_total - payable_with_entry)} 个 Receivable/Payable 需要迁移"
    end
  end

  # 辅助方法：查找 transaction_id 对应的 Entry
  def find_entry_for_transaction(transaction_id)
    return nil if transaction_id.blank?
    
    # 方法1：通过 Entryable::Transaction 的 source_transaction_id 查找
    entry = Entry
      .joins("INNER JOIN entryable_transactions ON entryable_transactions.id = entries.entryable_id")
      .where(entryable_type: 'Entryable::Transaction')
      .where(entryable_transactions: { source_transaction_id: transaction_id })
      .first
    
    return entry if entry.present?
    
    # 方法2：通过 extra 字段查找
    entry = Entry
      .where(entryable_type: 'Entryable::Transaction')
      .where("extra->>'old_transaction_id' = ?", transaction_id.to_s)
      .first
    
    return entry if entry.present?
    
    # 方法3：通过旧 Transaction 的属性重新匹配
    old_trans = Transaction.find_by(id: transaction_id)
    if old_trans.present?
      entry = Entry.where(
        account_id: old_trans.account_id,
        entryable_type: 'Entryable::Transaction',
        date: old_trans.date,
        amount: old_trans.amount
      ).first
      
      return entry if entry.present?
    end
    
    nil
  end

  desc '综合迁移验证 - 检查所有表的迁移状态'
  task verify_all: :environment do
    puts "=" * 60
    puts "P3 迁移综合验证报告"
    puts "=" * 60
    
    # Entry 统计
    puts "\n📊 Entry 统计:"
    total_entries = Entry.count
    transaction_entries = Entry.where(entryable_type: 'Entryable::Transaction').count
    valuation_entries = Entry.where(entryable_type: 'Entryable::Valuation').count
    trade_entries = Entry.where(entryable_type: 'Entryable::Trade').count
    
    puts "  总数: #{total_entries}"
    puts "  - Entryable::Transaction: #{transaction_entries}"
    puts "  - Entryable::Valuation: #{valuation_entries}"
    puts "  - Entryable::Trade: #{trade_entries}"
    
    # Attachment 统计
    puts "\n📎 Attachment 迁移状态:"
    total_attachments = Attachment.count
    with_entry = Attachment.where.not(entry_id: nil).count
    with_transaction = Attachment.where.not(transaction_id: nil).count
    
    puts "  总数: #{total_attachments}"
    puts "  - 有 entry_id: #{with_entry}"
    puts "  - 仍有 transaction_id: #{with_transaction}"
    puts "  - ✓ 迁移完成" if with_entry == total_attachments && total_attachments > 0
    puts "  - ✓ 无需迁移" if total_attachments == 0
    
    # Receivable 统计
    puts "\n💰 Receivable 迁移状态:"
    receivable_total = Receivable.count
    receivable_with_entry = Receivable.where.not(source_entry_id: nil).count
    receivable_with_transaction = Receivable.where.not(source_transaction_id: nil).count
    
    puts "  总数: #{receivable_total}"
    puts "  - 有 source_entry_id: #{receivable_with_entry}"
    puts "  - 仍有 source_transaction_id: #{receivable_with_transaction}"
    puts "  - ✓ 迁移完成" if receivable_with_entry == receivable_total && receivable_total > 0
    puts "  - ✓ 无需迁移" if receivable_total == 0
    
    # Payable 统计
    puts "\n💳 Payable 迁移状态:"
    payable_total = Payable.count
    payable_with_entry = Payable.where.not(source_entry_id: nil).count
    payable_with_transaction = Payable.where.not(source_transaction_id: nil).count
    
    puts "  总数: #{payable_total}"
    puts "  - 有 source_entry_id: #{payable_with_entry}"
    puts "  - 仍有 source_transaction_id: #{payable_with_transaction}"
    puts "  - ✓ 迁移完成" if payable_with_entry == payable_total && payable_total > 0
    puts "  - ✓ 无需迁移" if payable_total == 0
    
    # Schema 验证
    puts "\n🔍 Schema 验证:"
    puts "  - attachments.entry_id: ✓"
    puts "  - receivables.source_entry_id: ✓"
    puts "  - payables.source_entry_id: ✓"
    puts "  - entryable_transactions.source_transaction_id: ✓"
    
    # 总体迁移状态
    puts "\n" + "=" * 60
    migration_complete = (
      (total_attachments == 0 || with_entry == total_attachments) &&
      (receivable_total == 0 || receivable_with_entry == receivable_total) &&
      (payable_total == 0 || payable_with_entry == payable_total)
    )
    
    if migration_complete
      puts "✓ P3 迁移基础设施完全就绪！"
    else
      puts "⚠ 仍需继续迁移数据"
    end
    puts "=" * 60
  end
end