class CreateEventBudgets < ActiveRecord::Migration[8.0]
  def change
    create_table :event_budgets do |t|
      t.string :name, limit: 100, null: false
      t.text :description
      t.decimal :total_amount, precision: 10, scale: 2, null: false
      t.decimal :spent_amount, precision: 10, scale: 2, default: 0, null: false
      t.date :start_date, null: false
      t.date :end_date
      t.string :status, limit: 20, default: "active", null: false
      t.string :currency, limit: 3, default: "CNY"
      t.timestamps
    end

    add_index :event_budgets, :status
    add_index :event_budgets, :start_date
    add_index :event_budgets, :end_date
  end
end
