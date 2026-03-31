class AddTransactionIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :transactions, :target_account_id unless index_exists?(:transactions, :target_account_id)
    add_index :transactions, [:account_id, :date] unless index_exists?(:transactions, [:account_id, :date])
    add_index :transactions, [:target_account_id, :date] unless index_exists?(:transactions, [:target_account_id, :date])
    add_index :transactions, [:account_id, :date, :type] unless index_exists?(:transactions, [:account_id, :date, :type])
    add_index :transactions, :date unless index_exists?(:transactions, :date)
  end
end
