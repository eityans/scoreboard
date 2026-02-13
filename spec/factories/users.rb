FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    display_name { Faker::Name.name }
    provider { "google_oauth2" }
    sequence(:uid) { |n| "google_uid_#{n}" }
    password { Devise.friendly_token[0, 20] }
  end
end
