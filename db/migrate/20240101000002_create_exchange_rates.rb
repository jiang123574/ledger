class CreateExchangeRates < ActiveRecord::Migration[8.0]
  def change
    create_table :exchange_rates do |t|
      t.string :from_currency, limit: 3, null: false
      t.string :to_currency, limit: 3, null: false
      t.decimal :rate, precision: 12, scale: 6, null: false
      t.datetime :date, null: false
      t.string :source, limit: 50
      t.timestamps
    end
    add_index :exchange_rates, :from_currency
    add_index :exchange_rates, :to_currency
    add_index :exchange_rates, :date
  end
end
