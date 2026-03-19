class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, limit: 50, null: false
      t.string :color, limit: 7, default: "#3498db"
      t.timestamps
    end
    add_index :tags, :name, unique: true
  end
end
