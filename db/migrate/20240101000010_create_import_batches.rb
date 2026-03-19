class CreateImportBatches < ActiveRecord::Migration[8.0]
  def change
    create_table :import_batches do |t|
      t.string :source_name
      t.text :summary
      t.text :records
      t.timestamps
    end
    add_index :import_batches, :created_at
  end
end
