FactoryBot.define do
  factory :transaction do
    sequence(:sedi_transaction_id) { |n| 4_000_000 + n }
    transaction_date  { Date.today - 30 }
    filing_date       { Date.today - 25 }
    number_of_securities { 1000 }
    unit_price        { 10.50 }
    balance           { 50_000 }
    association :insider
    association :security_designation
    association :issuer
    association :ownership_type
    association :nature_of_transaction
  end
end
