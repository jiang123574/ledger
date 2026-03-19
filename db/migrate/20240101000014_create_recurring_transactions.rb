class CreateRecurringTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_transactions do |t|
      t.string :type, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, limit: 3, default: "CNY"
      t.references :category, foreign_key: { to_table: :categories }, null: true
      t.references :account, foreign_key: { to_table: :accounts }, null: false
      t.string :note
      t.string :frequency, null: false
      t.datetime :next_date, null: false
      t.integer :is_active, default: 1
      t.timestamps
    end
  end
end
