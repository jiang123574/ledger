class RemoveLegacyFieldsFromReceivables < ActiveRecord::Migration[8.1]
  def change
    remove_column :receivables, :source_entry_id, :integer if column_exists?(:receivables, :source_entry_id)
    remove_column :receivables, :source_transaction_id, :integer if column_exists?(:receivables, :source_transaction_id)
  end

  def column_exists?(table, column)
    ActiveRecord::Base.connection.columns(table).any? { |c| c.name == column.to_s }
  end
end
