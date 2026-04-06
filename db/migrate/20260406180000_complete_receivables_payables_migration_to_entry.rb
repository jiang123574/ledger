# frozen_string_literal: true

class CompleteReceivablesPayablesMigrationToEntry < ActiveRecord::Migration[7.0]
  def up
    Rails.logger.info "开始迁移 Receivable/Payable 数据..."

    # 迁移 Receivable
    Receivable.find_each do |receivable|
      next if receivable.source_entry_id.present?
      next if receivable.source_transaction_id.nil?

      entry = find_entry_for_transaction(receivable.source_transaction_id)
      if entry.present?
        receivable.update_column(:source_entry_id, entry.id)
      else
        Rails.logger.warn "找不到 Receivable #{receivable.id} 对应的 Entry (transaction_id: #{receivable.source_transaction_id})"
      end
    end

    # 迁移 Payable
    Payable.find_each do |payable|
      next if payable.source_entry_id.present?
      next if payable.source_transaction_id.nil?

      entry = find_entry_for_transaction(payable.source_transaction_id)
      if entry.present?
        payable.update_column(:source_entry_id, entry.id)
      else
        Rails.logger.warn "找不到 Payable #{payable.id} 对应的 Entry (transaction_id: #{payable.source_transaction_id})"
      end
    end

    Rails.logger.info "迁移完成！"
  end

  def down
    # 不支持回滚此复杂迁移
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def find_entry_for_transaction(transaction_id)
    return nil if transaction_id.nil?

    # 直接查找
    Entry
      .joins("INNER JOIN entryable_transactions ON entryable_transactions.id = entries.entryable_id")
      .where(entryable_type: 'Entryable::Transaction')
      .where(entryable_transactions: { source_transaction_id: transaction_id })
      .first
  end
end
