class CreateBudgets < ActiveRecord::Migration[8.0]
  def change
    create_table :budgets do |t|
      t.references :category, foreign_key: { to_table: :categories }, null: true
      t.string :month, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, limit: 3, default: "CNY"
      t.timestamps
    end
    add_index :budgets, :month
  end
end
