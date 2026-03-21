class DropEventBudgetsTables < ActiveRecord::Migration[8.1]
  def up
    drop_table :event_budget_transactions if table_exists?(:event_budget_transactions)
    drop_table :event_budgets if table_exists?(:event_budgets)
  end

  def down
    create_table :event_budgets do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :total_amount, precision: 15, scale: 2, null: false
      t.decimal :spent_amount, precision: 15, scale: 2, default: 0
      t.date :start_date, null: false
      t.date :end_date
      t.string :currency, default: "CNY"
      t.integer :status, default: 0
      t.timestamps
    end

    create_table :event_budget_transactions do |t|
      t.references :event_budget, null: false, foreign_key: true
      t.references :transaction, null: false, foreign_key: true
      t.timestamps
    end
  end
end