# 数据迁移：从 Transaction 模型迁移到 Entry 模型
# 
# 步骤：
# 1. 创建 Tagging 模型关联表（如果不存在）
# 2. 迁移 transactions 数据到 entries + entryable_transactions
# 3. 迁移 transaction_tags 到 taggings
# 4. 迁移 attachments 关联

class MigrateTransactionsToEntries < ActiveRecord::Migration[8.1]
  def up
    # Step 1: 创建 taggings 表（用于 polymorphic 关联）
    create_taggings_table_if_needed
    
    # Step 2: 迁移 transactions 数据
    migrate_transactions_data
    
    # Step 3: 迁移标签关联
    migrate_transaction_tags
    
    # Step 4: 迁移附件关联
    migrate_attachments
  end

  def down
    # 回滚：删除迁移后的数据
    Entry.where(entryable_type: 'Entryable::Transaction').find_each do |entry|
      entry.entryable&.destroy
      entry.destroy
    end
    
    # 删除 taggings 中与 entryable_transactions 相关的记录
    Tagging.where(taggable_type: 'Entryable::Transaction').delete_all
  end

  private

  def create_taggings_table_if_needed
    unless table_exists?(:taggings)
      create_table :taggings do |t|
        t.references :tag, null: false, foreign_key: true
        t.references :taggable, polymorphic: true, null: false
        t.datetime :created_at, null: false
        t.index [:taggable_type, :taggable_id, :tag_id], name: 'index_taggings_uniqueness', unique: true
      end
    end
  end

  def migrate_transactions_data
    # 批量迁移，避免内存溢出
    Transaction.find_in_batches(batch_size: 500) do |batch|
      batch.each do |t|
        # 只迁移非转账类型的交易
        # 转账类型需要特殊处理
        next if t.type == 'TRANSFER'
        
        # 创建 Entryable::Transaction
        entryable_trans = Entryable::Transaction.new(
          kind: t.type.downcase, # INCOME -> income, EXPENSE -> expense
          category_id: t.category_id,
          extra: t.extra || {},
          locked_attributes: t.locked_attributes || {}
        )
        entryable_trans.save(validate: false)  # 跳过验证
        
        # 创建 Entry
        name = t.note.present? ? t.note : "#{t.type == 'INCOME' ? '收入' : '支出'} #{t.amount}"
        
        entry = Entry.new(
          account_id: t.account_id,
          date: t.date,
          name: name,
          amount: t.amount.to_d,
          currency: t.currency || 'CNY',
          notes: t.note,
          entryable: entryable_trans,
          excluded: false,
          extra: {},
          locked_attributes: {},
          user_modified: t.user_modified || false,
          import_locked: false
        )
        entry.save(validate: false)  # 跳过验证
      end
    end
    
    # 处理转账类型
    migrate_transfers
  end

  def migrate_transfers
    # 转账需要特殊处理：创建 Entryable::Transaction 并设置 transfer_id
    Transaction.where(type: 'TRANSFER').find_in_batches(batch_size: 500) do |batch|
      batch.each do |t|
        transfer_id = generate_transfer_id
        
        # 转出记录
        entryable_out = Entryable::Transaction.new(
          kind: 'expense',
          extra: { transfer_note: t.note },
          locked_attributes: {}
        )
        entryable_out.save(validate: false)
        
        name_out = t.note.present? ? t.note : "转账出 #{t.amount}"
        entry_out = Entry.new(
          account_id: t.account_id,
          date: t.date,
          name: name_out,
          amount: -t.amount.to_d,  # 转出为负数
          currency: t.currency || 'CNY',
          notes: t.note,
          entryable: entryable_out,
          transfer_id: transfer_id
        )
        entry_out.save(validate: false)
        
        # 转入记录
        entryable_in = Entryable::Transaction.new(
          kind: 'income',
          extra: { transfer_note: t.note },
          locked_attributes: {}
        )
        entryable_in.save(validate: false)
        
        name_in = t.note.present? ? t.note : "转账入 #{t.amount}"
        entry_in = Entry.new(
          account_id: t.target_account_id,
          date: t.date,
          name: name_in,
          amount: t.amount.to_d,  # 转入为正数
          currency: t.currency || 'CNY',
          notes: t.note,
          entryable: entryable_in,
          transfer_id: transfer_id
        )
        entry_in.save(validate: false)
      end
    end
  end

  def migrate_transaction_tags
    # 迁移 transaction_tags 到 taggings (polymorphic)
    TransactionTag.find_in_batches(batch_size: 1000) do |batch|
      batch.each do |tt|
        # 找到对应的 entryable_transaction
        trans = Transaction.find_by(id: tt.transaction_id)
        next unless trans
        
        # 找到对应的 entry
        entry = Entry.find_by(
          account_id: trans.account_id,
          date: trans.date,
          amount: trans.amount
        )
        next unless entry
        
        # 创建 tagging
        Tagging.create!(
          tag_id: tt.tag_id,
          taggable: entry.entryable,
          created_at: tt.created_at || Time.current
        )
      end
    end
  end

  def migrate_attachments
    # 更新 attachments 的关联
    Attachment.find_each do |att|
      trans = Transaction.find_by(id: att.transaction_id)
      next unless trans
      
      # 找到对应的 entry
      entry = Entry.find_by(
        account_id: trans.account_id,
        date: trans.date,
        amount: trans.amount
      )
      next unless entry
      
      # 更新 attachment 关联（如果 attachments 表支持 polymorphic）
      # 或者创建新的关联方式
    end
  end

  def generate_transfer_id
    # 生成唯一的 transfer_id
    SecureRandom.uuid.gsub('-', '').to_i(16) % 2_000_000_000
  end
end