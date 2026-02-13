FactoryBot.define do
  factory :membership do
    user
    group
    role { "member" }

    trait :owner do
      role { "owner" }
    end
  end
end
