# frozen_string_literal: true

class AddRefundOfEntryIdToEntryableTransactions < ActiveRecord::Migration[7.0]
  def change
    add_column :entryable_transactions, :refund_of_entry_id, :uuid, null: true
    add_index :entryable_transactions, :refund_of_entry_id
  end
end
