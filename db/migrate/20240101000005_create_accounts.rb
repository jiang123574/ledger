class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :account_type
      t.decimal :initial_balance, precision: 10, scale: 2, default: 0.00
      t.string :currency, limit: 3, default: "CNY"
      t.integer :billing_day
      t.integer :due_day
      t.decimal :credit_limit, precision: 10, scale: 2
      t.integer :include_in_total, default: 1
      t.integer :hidden, default: 0
      t.integer :sort_order, default: 0
    end
    add_index :accounts, :name, unique: true
  end
end
