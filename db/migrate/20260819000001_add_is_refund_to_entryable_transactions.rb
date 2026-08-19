# frozen_string_literal: true

class AddIsRefundToEntryableTransactions < ActiveRecord::Migration[7.0]
  def change
    add_column :entryable_transactions, :is_refund, :boolean, default: false, null: false
    add_index :entryable_transactions, :is_refund
  end
end
