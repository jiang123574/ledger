class RemoveDuplicateIndexes < ActiveRecord::Migration[8.1]
  def up
    remove_index :budgets, name: 'idx_budgets_month_category'
    remove_index :transactions, name: 'idx_trans_account_date'
  end

  def down
    add_index :budgets, [ :month, :category_id ], name: 'idx_budgets_month_category'
    add_index :transactions, [ :account_id, :date ], name: 'idx_trans_account_date'
  end
end
