class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :group

  validates :user_id, uniqueness: { scope: :group_id }
  validates :role, presence: true, inclusion: { in: %w[owner member] }
end
