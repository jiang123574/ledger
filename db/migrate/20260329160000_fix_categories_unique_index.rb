class FixCategoriesUniqueIndex < ActiveRecord::Migration[8.1]
  def change
    # 移除全局唯一性约束
    remove_index :categories, :name, if_exists: true
    
    # 添加 (name, parent_id) 的复合唯一性约束
    add_index :categories, [:name, :parent_id], unique: true, name: "index_categories_on_name_and_parent_id"
  end
end
