class Player < ApplicationRecord
  belongs_to :group
  belongs_to :user, optional: true
  has_many :session_results, dependent: :restrict_with_error

  scope :active, -> { where(discarded_at: nil) }
  scope :discarded, -> { where.not(discarded_at: nil) }

  validates :display_name, presence: true, uniqueness: { scope: :group_id }

  def discard
    update(discarded_at: Time.current)
  end

  def discarded?
    discarded_at.present?
  end
end
