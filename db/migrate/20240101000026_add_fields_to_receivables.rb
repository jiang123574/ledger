class AddFieldsToReceivables < ActiveRecord::Migration[8.0]
  def change
    add_column :receivables, :description, :string
    add_column :receivables, :category, :string
    add_column :receivables, :date, :date, default: -> { "CURRENT_DATE" }
  end
end
