class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.integer :sedi_transaction_id,      null: false
      t.date    :transaction_date,         null: false
      t.date    :filing_date,              null: false
      t.integer :number_of_securities
      t.decimal :unit_price,               precision: 15, scale: 4
      t.integer :balance
      t.references :insider,               null: false, foreign_key: true
      t.references :security_designation,  null: false, foreign_key: true
      t.references :issuer,                null: false, foreign_key: true
      t.references :ownership_type,        null: false, foreign_key: true
      t.references :nature_of_transaction, null: false, foreign_key: true
      t.timestamps
    end
    add_index :transactions,
      [:sedi_transaction_id, :transaction_date, :security_designation_id, :ownership_type_id],
      unique: true,
      name: "index_transactions_on_sedi_id_and_date_and_security_and_ownership"
  end
end
