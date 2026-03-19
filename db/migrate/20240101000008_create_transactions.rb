class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.datetime :date
      t.string :transaction_type
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency, limit: 3, default: "CNY"
      t.decimal :original_amount, precision: 12, scale: 6
      t.decimal :exchange_rate, precision: 12, scale: 6
      t.string :dedupe_key, limit: 40
      t.string :category
      t.references :category, foreign_key: { to_table: :categories }, null: true
      t.string :tag
      t.string :note
      t.references :account, foreign_key: { to_table: :accounts }, null: true
      t.references :target_account, foreign_key: { to_table: :accounts }, null: true
      t.references :receivable, foreign_key: { to_table: :receivables }, null: true
      t.references :link, foreign_key: { to_table: :transactions }, null: true
      t.integer :sort_order, default: 0
      t.timestamps
    end
    add_index :transactions, :date
    add_index :transactions, :transaction_type
    add_index :transactions, :category
    add_index :transactions, :dedupe_key
  end
end
