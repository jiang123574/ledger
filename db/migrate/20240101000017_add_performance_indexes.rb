class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :transactions, [:account_id, :date], name: "index_transactions_account_date"
    add_index :transactions, [:type, :date], name: "index_transactions_type_date"
    add_index :accounts, [:hidden, :include_in_total], name: "index_accounts_visibility"
    add_index :categories, [:type, :sort_order], name: "index_categories_type_order"
    add_index :budgets, [:month, :category_id], name: "index_budgets_month_category"
  end
end
