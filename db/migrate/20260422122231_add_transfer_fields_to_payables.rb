class AddTransferFieldsToPayables < ActiveRecord::Migration[8.1]
  def change
    add_column :payables, :transfer_id, :string
    add_column :payables, :settlement_transfer_ids, :text
    add_index :payables, :transfer_id
    add_index :payables, :settlement_transfer_ids
  end
end
