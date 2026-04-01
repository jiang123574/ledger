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
    
    # 检查账户余额
    Account.find_each do |account|
      old_balance = account.sent_transactions.sum(:amount) - 
                    account.received_transactions.where(type: 'TRANSFER').sum(:amount)
      
      new_balance = Entry.where(account_id: account.id)
                        .joins("JOIN entryable_transactions ON entryable_transactions.id = entries.entryable_id")
                        .where("entries.entryable_type = 'Entryable::Transaction'")
                        .sum("CASE WHEN entryable_transactions.kind = 'income' THEN entries.amount ELSE -entries.amount END")
      
      if old_balance != new_balance
        puts "警告: 账户 #{account.name} (ID: #{account.id}) 余额不匹配"
        puts "  旧余额: #{old_balance}"
        puts "  新余额: #{new_balance}"
      end
    end
    
    puts "验证完成！"
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