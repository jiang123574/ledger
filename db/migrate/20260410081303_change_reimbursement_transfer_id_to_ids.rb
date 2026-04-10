class ChangeReimbursementTransferIdToIds < ActiveRecord::Migration[8.1]
  def change
    remove_index :receivables, :reimbursement_transfer_id if index_exists?(:receivables, :reimbursement_transfer_id)
    remove_column :receivables, :reimbursement_transfer_id if column_exists?(:receivables, :reimbursement_transfer_id)

    add_column :receivables, :reimbursement_transfer_ids, :text
    add_index :receivables, :reimbursement_transfer_ids
  end

  def index_exists?(table, column)
    ActiveRecord::Base.connection.indexes(table).any? { |i| i.name == "index_#{table}_on_#{column}" }
  end

  def column_exists?(table, column)
    ActiveRecord::Base.connection.columns(table).any? { |c| c.name == column.to_s }
  end
end
