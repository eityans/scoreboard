FactoryBot.define do
  factory :poker_session do
    group
    association :created_by, factory: :user
    played_on { Date.current }
    note { nil }

    trait :live do
      status { "in_progress" }
      recorded_live { true }
    end
  end
end
