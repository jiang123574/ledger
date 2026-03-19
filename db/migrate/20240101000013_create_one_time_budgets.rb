class CreateOneTimeBudgets < ActiveRecord::Migration[8.0]
  def change
    create_table :one_time_budgets do |t|
      t.string :name, limit: 100, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, limit: 3, default: "CNY"
      t.references :category, foreign_key: { to_table: :categories }, null: true
      t.datetime :start_date, null: false
      t.datetime :end_date
      t.string :status, limit: 20, default: "active"
      t.text :note
      t.timestamps
    end
  end
end
