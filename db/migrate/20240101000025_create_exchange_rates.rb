class CreateExchangeRates < ActiveRecord::Migration[7.2]
  def change
    create_table :exchange_rates do |t|
      t.string :from_currency, limit: 3, null: false
      t.string :to_currency, limit: 3, null: false
      t.decimal :rate, precision: 15, scale: 6, null: false
      t.date :date, null: false
      t.string :source, default: 'manual'

      t.timestamps
    end

    add_index :exchange_rates, [ :from_currency, :to_currency, :date ], unique: true
  end
end