class AddActualAvailableCreditToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :actual_available_credit, :decimal, precision: 10, scale: 2
  end
end
