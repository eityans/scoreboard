class PokerSession < ApplicationRecord
  belongs_to :group
  belongs_to :created_by, class_name: "User"
  has_many :session_results, dependent: :destroy
  has_many :players, through: :session_results

  accepts_nested_attributes_for :session_results, allow_destroy: true, reject_if: :all_blank

  validates :played_on, presence: true
end
