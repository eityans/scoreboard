FactoryBot.define do
  factory :session_result do
    poker_session
    player
    amount { Faker::Number.between(from: -10000, to: 10000) }
  end
end
