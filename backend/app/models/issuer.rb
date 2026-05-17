class Issuer < ApplicationRecord
  has_many :transactions

  validates :name, presence: true
  validates :ticker, uniqueness: true, allow_nil: true
end
