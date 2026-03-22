class AddReceivableAssociations < ActiveRecord::Migration[8.0]
  def change
    add_reference :receivables, :counterparty, foreign_key: true, null: true
    add_reference :receivables, :account, foreign_key: true, null: true
  end
end
