FactoryBot.define do
  factory :player do
    group
    user { nil }
    sequence(:display_name) { |n| "Player #{n}" }
  end
end
