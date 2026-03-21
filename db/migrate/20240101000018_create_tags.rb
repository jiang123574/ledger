class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false, limit: 50
      t.string :color, limit: 7, default: "#3498db"
      t.text :description

      t.timestamps
    end

    add_index :tags, :name, unique: true
  end
end