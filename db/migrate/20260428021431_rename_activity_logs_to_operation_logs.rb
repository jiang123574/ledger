class RenameActivityLogsToOperationLogs < ActiveRecord::Migration[8.1]
  def up
    # 重命名表
    rename_table :activity_logs, :operation_logs

    # 重命名索引
    indexes_to_rename = {
      'index_activity_logs_on_action' => 'index_operation_logs_on_action',
      'index_activity_logs_on_created_at' => 'index_operation_logs_on_created_at',
      'index_activity_logs_on_item' => 'index_operation_logs_on_item',
      'index_activity_logs_on_item_type_and_item_id' => 'index_operation_logs_on_item_type_and_item_id'
    }

    indexes_to_rename.each do |old_name, new_name|
      if index_exists?(:operation_logs, old_name)
        rename_index :operation_logs, old_name, new_name
      end
    end

    # 添加新字段
    add_column :operation_logs, :request_path, :string unless column_exists?(:operation_logs, :request_path)
    add_column :operation_logs, :request_method, :string, limit: 10 unless column_exists?(:operation_logs, :request_method)
    add_column :operation_logs, :request_params, :json unless column_exists?(:operation_logs, :request_params)
    add_column :operation_logs, :user_agent, :string unless column_exists?(:operation_logs, :user_agent)
    add_column :operation_logs, :response_status, :integer unless column_exists?(:operation_logs, :response_status)

    # 添加新索引（避免重复）
    add_index :operation_logs, :request_path unless index_exists?(:operation_logs, :request_path)
    # created_at 索引已经在 rename_index 时创建，不需要再添加
  end

  def down
    # 移除新索引
    remove_index :operation_logs, :request_path if index_exists?(:operation_logs, :request_path)

    # 移除新字段
    remove_column :operation_logs, :response_status if column_exists?(:operation_logs, :response_status)
    remove_column :operation_logs, :user_agent if column_exists?(:operation_logs, :user_agent)
    remove_column :operation_logs, :request_params if column_exists?(:operation_logs, :request_params)
    remove_column :operation_logs, :request_method if column_exists?(:operation_logs, :request_method)
    remove_column :operation_logs, :request_path if column_exists?(:operation_logs, :request_path)

    # 重命名索引
    indexes_to_rename = {
      'index_operation_logs_on_action' => 'index_activity_logs_on_action',
      'index_operation_logs_on_created_at' => 'index_activity_logs_on_created_at',
      'index_operation_logs_on_item' => 'index_activity_logs_on_item',
      'index_operation_logs_on_item_type_and_item_id' => 'index_activity_logs_on_item_type_and_item_id'
    }

    indexes_to_rename.each do |old_name, new_name|
      if index_exists?(:operation_logs, old_name)
        rename_index :operation_logs, old_name, new_name
      end
    end

    # 重命名表
    rename_table :operation_logs, :activity_logs
  end
end
