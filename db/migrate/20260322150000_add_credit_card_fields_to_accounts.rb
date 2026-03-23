class AddCreditCardFieldsToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :billing_day_mode, :string, default: "current"
    add_column :accounts, :due_day_mode, :string, default: "fixed"
    add_column :accounts, :due_day_offset, :integer
  end
end
