class SessionEntry < ApplicationRecord
  belongs_to :poker_session
  belongs_to :player
  belongs_to :recorded_by, class_name: "User"

  enum :kind, { join: "join", rebuy: "rebuy", cash_out: "cash_out", adjustment: "adjustment" }, scopes: false

  validates :amount, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, unless: :adjustment?
  validate :player_belongs_to_session_group

  private

  def player_belongs_to_session_group
    return if player.nil? || poker_session.nil?

    errors.add(:player, "はこのグループのプレイヤーではありません") unless player.group_id == poker_session.group_id
  end
end
