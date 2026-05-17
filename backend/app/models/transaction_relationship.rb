class TransactionRelationship < ApplicationRecord
  belongs_to :transaction
  belongs_to :relationship

  validates :transaction_id, uniqueness: { scope: :relationship_id }
end
