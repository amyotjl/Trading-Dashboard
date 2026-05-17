class OwnershipType < ApplicationRecord
  has_many :transactions

  validates :category, presence: true, inclusion: { in: %w[Direct Indirect] }
  validates :category, uniqueness: { scope: :entity_name }
end
