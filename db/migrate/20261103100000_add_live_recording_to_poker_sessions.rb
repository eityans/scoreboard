class AddLiveRecordingToPokerSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :poker_sessions, :status, :string, null: false, default: "completed"
    add_column :poker_sessions, :recorded_live, :boolean, null: false, default: false
  end
end
