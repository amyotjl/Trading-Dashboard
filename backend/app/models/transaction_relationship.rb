class TransactionRelationship < ApplicationRecord
  belongs_to :sedi_transaction, class_name: "Transaction", foreign_key: :transaction_id
  belongs_to :relationship

  validates :transaction_id, uniqueness: { scope: :relationship_id }
end
