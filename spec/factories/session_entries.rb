FactoryBot.define do
  factory :session_entry do
    poker_session
    player { association :player, group: poker_session.group }
    association :recorded_by, factory: :user
    kind { "join" }
    amount { 300 }
  end
end
