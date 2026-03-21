class UpdateExchangeRatesStructure < ActiveRecord::Migration[8.0]
  def change
    # 添加唯一复合索引（如果不存在）
    unless index_exists?(:exchange_rates, [:from_currency, :to_currency, :date])
      add_index :exchange_rates, [:from_currency, :to_currency, :date], unique: true
    end

    # 设置 source 默认值
    change_column_default :exchange_rates, :source, 'manual'
  end
end