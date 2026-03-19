class CreateCurrencies < ActiveRecord::Migration[8.0]
  def change
    create_table :currencies do |t|
      t.string :code, limit: 3, null: false
      t.string :name, limit: 50, null: false
      t.string :symbol, limit: 10, null: false
      t.integer :is_default, default: 0
      t.decimal :exchange_rate, precision: 12, scale: 6, default: 1.0
      t.timestamps
    end
    add_index :currencies, :code, unique: true
  end
end
