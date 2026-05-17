class NatureOfTransaction < ApplicationRecord
  has_many :transactions

  validates :code,        presence: true
  validates :description, presence: true
  validates :code, uniqueness: { scope: :description }
end
