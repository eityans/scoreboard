FactoryBot.define do
  factory :player do
    group
    user { nil }
    display_name { Faker::Name.name }
  end
end
