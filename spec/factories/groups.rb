FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "ポーカー会 #{n}" }
    association :created_by, factory: :user
  end
end
