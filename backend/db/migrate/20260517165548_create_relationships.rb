class CreateRelationships < ActiveRecord::Migration[8.0]
  def change
    create_table :relationships do |t|
      t.string :code,        null: false
      t.string :description, null: false
      t.timestamps
    end
    add_index :relationships, [:code, :description], unique: true
  end
end
