FactoryBot.define do
  factory :nature_of_transaction do
    sequence(:code) { |n| n.to_s.rjust(2, "0") }
    description { Faker::Lorem.sentence(word_count: 3) }
  end
end
