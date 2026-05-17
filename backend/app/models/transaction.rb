class Transaction < ApplicationRecord
  belongs_to :insider
  belongs_to :security_designation
  belongs_to :issuer
  belongs_to :ownership_type
  belongs_to :nature_of_transaction

  has_many :transaction_relationships
  has_many :relationships, through: :transaction_relationships

  validates :sedi_transaction_id, presence: true
  validates :transaction_date,    presence: true
  validates :filing_date,         presence: true
  validates :sedi_transaction_id, uniqueness: {
    scope: [:transaction_date, :security_designation_id, :ownership_type_id],
    message: "duplicate transaction"
  }

  scope :for_ticker, ->(ticker) {
    joins(:issuer).where(issuers: { ticker: ticker })
  }

  scope :filtered, ->(params) {
    scope = all
    scope = scope.where("transaction_date >= ?", params[:date_from]) if params[:date_from].present?
    scope = scope.where("transaction_date <= ?", params[:date_to])   if params[:date_to].present?
    scope = scope.joins(:issuer).where(issuers: { ticker: params[:ticker] }) if params[:ticker].present?
    scope = scope.joins(:insider).where("insiders.name ILIKE ?", "%#{params[:insider_name]}%") if params[:insider_name].present?
    scope = scope.where(nature_of_transaction_id: params[:nature_of_transaction_id]) if params[:nature_of_transaction_id].present?
    scope
  }

  SORTABLE_COLUMNS = %w[transaction_date filing_date number_of_securities unit_price balance].freeze

  scope :sorted, ->(column, direction) {
    col = SORTABLE_COLUMNS.include?(column) ? column : "filing_date"
    dir = %w[asc desc].include?(direction&.downcase) ? direction.downcase : "desc"
    order("#{col} #{dir}")
  }
end
