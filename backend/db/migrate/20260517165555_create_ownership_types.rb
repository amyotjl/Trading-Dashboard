class CreateOwnershipTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :ownership_types do |t|
      t.string :category,    null: false  # "Direct" or "Indirect"
      t.string :entity_name              # null for Direct; entity name for Indirect
      t.timestamps
    end
    add_index :ownership_types, [:category, :entity_name], unique: true
  end
end
