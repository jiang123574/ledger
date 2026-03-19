class CreateBackupRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :backup_records do |t|
      t.string :filename, null: false
      t.string :file_path, limit: 500, null: false
      t.integer :file_size, default: 0
      t.string :backup_type, limit: 20, default: "manual"
      t.string :status, limit: 20, default: "completed"
      t.string :note, limit: 500
      t.string :webdav_url, limit: 500
      t.timestamps
    end
  end
end
