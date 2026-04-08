class MigrateReceivablesCounterpartyToForeignKey < ActiveRecord::Migration[7.0]
  def up
    # 创建缺失的 Counterparty 记录（幂等：ON CONFLICT DO NOTHING）
    execute <<~SQL.squish
      INSERT INTO counterparties (name)
      SELECT DISTINCT receivables.counterparty
      FROM receivables
      LEFT JOIN counterparties ON counterparties.name = receivables.counterparty
      WHERE receivables.counterparty IS NOT NULL
        AND receivables.counterparty <> ''
        AND counterparties.id IS NULL
      ON CONFLICT (name) DO NOTHING
    SQL

    # 将 receivables.counterparty 值迁移到 receivables.counterparty_id
    execute <<~SQL.squish
      UPDATE receivables
      SET counterparty_id = counterparties.id
      FROM counterparties
      WHERE receivables.counterparty_id IS NULL
        AND receivables.counterparty = counterparties.name
        AND receivables.counterparty IS NOT NULL
    SQL

    # 删除旧的 counterparty 字符串列
    remove_column :receivables, :counterparty, :string
  end

  def down
    # 恢复 counterparty 字符串列
    add_column :receivables, :counterparty, :string

    # 从 counterparty_id 恢复数据到 counterparty
    execute <<~SQL.squish
      UPDATE receivables
      SET counterparty = counterparties.name
      FROM counterparties
      WHERE receivables.counterparty_id = counterparties.id
        AND receivables.counterparty IS NULL
    SQL
  end
end
