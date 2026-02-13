FactoryBot.define do
  factory :poker_session do
    group
    association :created_by, factory: :user
    played_on { Date.current }
    note { nil }
  end
end
