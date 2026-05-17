class Relationship < ApplicationRecord
  has_many :transaction_relationships
  has_many :transactions, through: :transaction_relationships

  validates :code,        presence: true
  validates :description, presence: true
  validates :code, uniqueness: { scope: :description }
end
