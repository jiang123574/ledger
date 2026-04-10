class AddTransferFieldsToReceivables < ActiveRecord::Migration[7.2]
  def change
    add_column :receivables, :transfer_id, :integer
    add_column :receivables, :reimbursement_transfer_id, :integer
    add_index :receivables, :transfer_id
    add_index :receivables, :reimbursement_transfer_id
  end
end
