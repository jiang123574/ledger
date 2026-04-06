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
end