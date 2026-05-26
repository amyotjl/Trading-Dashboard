FactoryBot.define do
  factory :ownership_type do
    category { "Direct" }
    entity_name { nil }

    skip_create
    initialize_with { OwnershipType.find_or_create_by!(category: category, entity_name: entity_name) }

    trait :indirect do
      category { "Indirect" }
      sequence(:entity_name) { |n| "Holding Corp #{n}" }
    end
  end
end
