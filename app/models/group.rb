class Group < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :players, dependent: :destroy
  has_many :poker_sessions, dependent: :destroy

  validates :name, presence: true
  validates :invitation_token, presence: true, uniqueness: true

  before_validation :generate_invitation_token, on: :create

  private

  def generate_invitation_token
    self.invitation_token ||= SecureRandom.urlsafe_base64(16)
  end
end
