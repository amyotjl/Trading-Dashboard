FactoryBot.define do
  factory :ownership_type do
    category { "Direct" }
    entity_name { nil }

    trait :indirect do
      category { "Indirect" }
      sequence(:entity_name) { |n| "Holding Corp #{n}" }
    end
  end
end
