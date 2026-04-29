class CreateOperationLogs < ActiveRecord::Migration[8.1]
  def up
    # 如果表已存在，跳过
    return if table_exists?(:operation_logs)

    # 如果 activity_logs 存在，重命名
    if table_exists?(:activity_logs)
      rename_table :activity_logs, :operation_logs

      # 重命名索引
      rename_index :operation_logs, 'index_activity_logs_on_action', 'index_operation_logs_on_action' if index_exists?(:operation_logs, 'index_activity_logs_on_action')
      rename_index :operation_logs, 'index_activity_logs_on_created_at', 'index_operation_logs_on_created_at' if index_exists?(:operation_logs, 'index_activity_logs_on_created_at')
      rename_index :operation_logs, 'index_activity_logs_on_item', 'index_operation_logs_on_item' if index_exists?(:operation_logs, 'index_activity_logs_on_item')
      rename_index :operation_logs, 'index_activity_logs_on_item_type_and_item_id', 'index_operation_logs_on_item_type_and_item_id' if index_exists?(:operation_logs, 'index_activity_logs_on_item_type_and_item_id')
    else
      # 直接创建新表
      create_table :operation_logs do |t|
        t.string :action, null: false
        t.string :item_type, null: false
        t.bigint :item_id, null: false
        t.json :changeset
        t.text :description
        t.string :whodunnit
        t.string :request_path
        t.string :request_method, limit: 10
        t.json :request_params
        t.string :user_agent
        t.string :ip_address
        t.integer :response_status

        t.timestamps null: false
      end

      add_index :operation_logs, :action
      add_index :operation_logs, :created_at
      add_index :operation_logs, [ :item_type, :item_id ], name: 'index_operation_logs_on_item'
      add_index :operation_logs, :request_path
    end
  end

  def down
    if table_exists?(:operation_logs)
      drop_table :operation_logs
    end
  end
end
