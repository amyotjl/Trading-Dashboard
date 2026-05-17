FactoryBot.define do
  factory :security_designation do
    sequence(:name) { |n| "Common Shares #{n}" }
  end
end
