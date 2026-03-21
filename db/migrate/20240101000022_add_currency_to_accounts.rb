class AddCurrencyToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :accounts, :currency, :string, default: "CNY", null: false
  end
end