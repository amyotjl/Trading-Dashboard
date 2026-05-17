FactoryBot.define do
  factory :insider do
    sequence(:name) { |n| "#{Faker::Name.name} #{n}" }
  end
end
