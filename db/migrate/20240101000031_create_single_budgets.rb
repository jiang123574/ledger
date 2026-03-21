class CreateSingleBudgets < ActiveRecord::Migration[8.0]
  def change
    create_table :single_budgets do |t|
      t.string :name, limit: 100, null: false
      t.text :description
      t.decimal :total_amount, precision: 10, scale: 2, null: false
      t.decimal :spent_amount, precision: 10, scale: 2, default: 0, null: false
      t.date :start_date, null: false
      t.date :end_date
      t.string :status, limit: 20, default: "planning", null: false
      t.string :currency, limit: 3, default: "CNY"
      t.timestamps
    end

    create_table :budget_items do |t|
      t.references :single_budget, null: false, foreign_key: true
      t.string :name, limit: 100, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :spent_amount, precision: 10, scale: 2, default: 0, null: false
      t.string :category, limit: 50
      t.text :notes
      t.timestamps
    end

    add_index :single_budgets, :status
    add_index :single_budgets, :start_date
    add_index :single_budgets, :end_date
    add_index :budget_items, :category
  end
end
