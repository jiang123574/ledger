class CreateCurrencies < ActiveRecord::Migration[7.2]
  def change
    create_table :currencies do |t|
      t.string :code, limit: 3, null: false
      t.string :name, null: false
      t.string :symbol, null: false
      t.decimal :rate, precision: 15, scale: 6, default: 1.0
      t.boolean :is_default, default: false
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :currencies, :code, unique: true

    # 添加默认货币数据
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO currencies (code, name, symbol, rate, is_default, created_at, updated_at) VALUES
          ('CNY', '人民币', '¥', 1.0, true, NOW(), NOW()),
          ('USD', '美元', '$', 0.14, false, NOW(), NOW()),
          ('EUR', '欧元', '€', 0.13, false, NOW(), NOW()),
          ('GBP', '英镑', '£', 0.11, false, NOW(), NOW()),
          ('JPY', '日元', '¥', 21.0, false, NOW(), NOW()),
          ('HKD', '港币', 'HK$', 1.09, false, NOW(), NOW()),
          ('TWD', '新台币', 'NT$', 4.45, false, NOW(), NOW()),
          ('KRW', '韩元', '₩', 191.0, false, NOW(), NOW())
        SQL
      end
    end
  end
end