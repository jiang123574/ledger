class AddCategoryEnhancedFields < ActiveRecord::Migration[8.0]
  def change
    # 添加新字段（如果不存在）
    unless column_exists?(:categories, :color)
      add_column :categories, :color, :string, limit: 7, default: "#6b7280"
    end

    unless column_exists?(:categories, :icon)
      add_column :categories, :icon, :string
    end

    unless column_exists?(:categories, :active)
      add_column :categories, :active, :boolean, default: true
    end

    unless column_exists?(:categories, :level)
      add_column :categories, :level, :integer, default: 0
    end

    # 添加索引（如果不存在）
    unless index_exists?(:categories, :sort_order)
      add_index :categories, :sort_order
    end

    unless index_exists?(:categories, :active)
      add_index :categories, :active
    end

    unless index_exists?(:categories, :parent_id)
      add_index :categories, :parent_id
    end
  end
end