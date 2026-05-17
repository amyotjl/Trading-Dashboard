FactoryBot.define do
  factory :issuer do
    sequence(:name) { |n| "Company #{n} Inc." }
    sequence(:ticker) { |n| "TKR#{n}" }
    sector { nil }
    home_page { nil }
  end
end
