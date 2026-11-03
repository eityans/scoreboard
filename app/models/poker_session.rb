class PokerSession < ApplicationRecord
  belongs_to :group
  belongs_to :created_by, class_name: "User"
  has_many :session_results, dependent: :destroy
  has_many :players, through: :session_results
  has_many :session_entries, dependent: :delete_all

  enum :status, { in_progress: "in_progress", completed: "completed" }

  accepts_nested_attributes_for :session_results, allow_destroy: true, reject_if: :all_blank

  validates :played_on, presence: true

  def ledger
    SessionLedger.new(session_entries.includes(:player).order(:created_at, :id).to_a)
  end

  def finishable?
    return false unless in_progress?

    current = ledger
    current.any_join? && !current.any_seated?
  end

  def finish!
    with_lock do
      next false unless finishable?

      completed!
      sync_results!
      true
    end
  end

  def sync_results!
    return unless recorded_live? && completed?

    current = ledger
    if current.any_seated?
      in_progress!
      session_results.destroy_all
    else
      write_results(current.balances)
    end
  end

  def participant_count
    in_progress? ? session_entries.map(&:player_id).uniq.size : session_results.size
  end

  private

  def write_results(balances)
    session_results.where.not(player_id: balances.keys).destroy_all
    balances.each do |player_id, amount|
      session_results.find_or_initialize_by(player_id: player_id).update!(amount: amount)
    end
  end
end
