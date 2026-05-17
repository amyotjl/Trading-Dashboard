class CreateInsiders < ActiveRecord::Migration[8.0]
  def change
    create_table :insiders do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :insiders, :name, unique: true
  end
end
