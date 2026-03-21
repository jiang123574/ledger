class AddCurrencyToTransactions < ActiveRecord::Migration[7.2]
  def change
    add_column :transactions, :currency, :string, default: "CNY", null: false
    add_column :transactions, :original_amount, :decimal, precision: 15, scale: 2
  end
end