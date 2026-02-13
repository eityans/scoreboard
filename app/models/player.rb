class Player < ApplicationRecord
  belongs_to :group
  belongs_to :user, optional: true
  has_many :session_results, dependent: :destroy

  validates :display_name, presence: true, uniqueness: { scope: :group_id }
end
