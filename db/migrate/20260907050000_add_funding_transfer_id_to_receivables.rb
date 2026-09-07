# frozen_string_literal: true

class AddFundingTransferIdToReceivables < ActiveRecord::Migration[7.0]
  def change
    add_column :receivables, :funding_transfer_id, :string
    add_index :receivables, :funding_transfer_id
  end
end
