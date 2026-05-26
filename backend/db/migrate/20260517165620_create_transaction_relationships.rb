class CreateTransactionRelationships < ActiveRecord::Migration[8.0]
  def change
    create_table :transaction_relationships, id: false do |t|
      t.references :transaction,   null: false, foreign_key: true
      t.references :relationship,  null: false, foreign_key: true
    end
    add_index :transaction_relationships, [:transaction_id, :relationship_id], unique: true, name: "idx_txn_relationships_dedup"
  end
end
