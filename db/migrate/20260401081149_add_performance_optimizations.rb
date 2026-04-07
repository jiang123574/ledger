class AddPerformanceOptimizations < ActiveRecord::Migration[8.1]
  def change
    add_index :transactions, [ :account_id, :type, :date ],
              name: 'idx_trans_account_type_date'
    add_index :transactions, [ :target_account_id, :type, :date ],
              name: 'idx_trans_target_type_date'
    add_index :transactions, [ :type, :date, :account_id ],
              name: 'idx_trans_type_date_account'

    add_column :accounts, :transactions_count, :integer, default: 0, null: false
    add_column :accounts, :last_transaction_date, :date

    add_index :accounts, :last_transaction_date, name: 'idx_accounts_last_trans_date'
  end
end
