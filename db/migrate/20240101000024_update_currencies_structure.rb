class UpdateCurrenciesStructure < ActiveRecord::Migration[8.0]
  def change
    # 重命名 exchange_rate 为 rate
    rename_column :currencies, :exchange_rate, :rate if column_exists?(:currencies, :exchange_rate)

    # 添加 is_active 字段
    add_column :currencies, :is_active, :boolean, default: true unless column_exists?(:currencies, :is_active)

    # 修改 is_default 为 boolean
    reversible do |dir|
      dir.up do
        # 先删除默认值
        execute "ALTER TABLE currencies ALTER COLUMN is_default DROP DEFAULT"
        # 修改类型
        execute <<-SQL
          ALTER TABLE currencies 
          ALTER COLUMN is_default TYPE boolean 
          USING CASE WHEN is_default = 1 THEN true ELSE false END
        SQL
        # 设置新的默认值
        execute "ALTER TABLE currencies ALTER COLUMN is_default SET DEFAULT false"
      end

      dir.down do
        execute "ALTER TABLE currencies ALTER COLUMN is_default DROP DEFAULT"
        execute <<-SQL
          ALTER TABLE currencies 
          ALTER COLUMN is_default TYPE integer 
          USING CASE WHEN is_default THEN 1 ELSE 0 END
        SQL
        execute "ALTER TABLE currencies ALTER COLUMN is_default SET DEFAULT 0"
      end
    end
  end
end