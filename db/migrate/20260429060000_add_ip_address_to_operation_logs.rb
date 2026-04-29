class AddIpAddressToOperationLogs < ActiveRecord::Migration[8.1]
  def up
    add_column :operation_logs, :ip_address, :string unless column_exists?(:operation_logs, :ip_address)
  end

  def down
    remove_column :operation_logs, :ip_address if column_exists?(:operation_logs, :ip_address)
  end
end
