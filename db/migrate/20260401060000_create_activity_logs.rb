class CreateActivityLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_logs do |t|
      t.references :item, polymorphic: true, null: false
      t.string :action, null: false
      t.json :changes
      t.string :whodunnit
      t.string :ip_address
      t.text :description

      t.timestamps
    end

    add_index :activity_logs, [:item_type, :item_id]
    add_index :activity_logs, :action
    add_index :activity_logs, :created_at
  end
end