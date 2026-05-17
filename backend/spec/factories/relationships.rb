FactoryBot.define do
  factory :relationship do
    sequence(:code) { |n| n.to_s }
    description { Faker::Company.profession }
  end
end
