class CreateEventBudgetTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :event_budget_transactions do |t|
      t.references :event_budget, null: false, foreign_key: true
      t.references :transaction, null: false, foreign_key: true
      t.timestamps
    end

    add_index :event_budget_transactions, [:event_budget_id, :transaction_id], unique: true
  end
end
