class CreateNatureOfTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :nature_of_transactions do |t|
      t.string :code,        null: false
      t.string :description, null: false
      t.timestamps
    end
    add_index :nature_of_transactions, [:code, :description], unique: true
  end
end
