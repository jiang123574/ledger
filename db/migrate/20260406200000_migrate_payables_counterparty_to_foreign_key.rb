class MigratePayablesCounterpartyToForeignKey < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      INSERT INTO counterparties (name)
      SELECT DISTINCT payables.counterparty
      FROM payables
      LEFT JOIN counterparties ON counterparties.name = payables.counterparty
      WHERE payables.counterparty IS NOT NULL
        AND payables.counterparty <> ''
        AND counterparties.id IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE payables
      SET counterparty_id = counterparties.id
      FROM counterparties
      WHERE payables.counterparty_id IS NULL
        AND payables.counterparty = counterparties.name
    SQL

    remove_column :payables, :counterparty, :string
  end

  def down
    add_column :payables, :counterparty, :string

    execute <<~SQL.squish
      UPDATE payables
      SET counterparty = counterparties.name
      FROM counterparties
      WHERE payables.counterparty_id = counterparties.id
    SQL
  end
end
