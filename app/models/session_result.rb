class SessionResult < ApplicationRecord
  belongs_to :poker_session
  belongs_to :player

  validates :amount, presence: true
  validates :player_id, uniqueness: { scope: :poker_session_id }
end
