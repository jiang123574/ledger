class CreateAttachments < ActiveRecord::Migration[8.0]
  def change
    create_table :attachments do |t|
      t.references :transaction, foreign_key: { to_table: :transactions }, null: false
      t.string :file_path, limit: 500, null: false
      t.string :file_name, limit: 255, null: false
      t.integer :file_size, default: 0
      t.string :file_type, limit: 50, null: false
      t.string :thumbnail_path, limit: 500
      t.timestamps
    end
  end
end
