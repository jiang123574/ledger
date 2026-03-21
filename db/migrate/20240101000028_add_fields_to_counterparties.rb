class AddFieldsToCounterparties < ActiveRecord::Migration[8.1]
  def change
    add_column :counterparties, :contact, :string
    add_column :counterparties, :note, :text
  end
end
