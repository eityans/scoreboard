class AddLeaderboardDefaultsToGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :groups, :default_leaderboard_period, :string, null: false, default: "latest"
    add_column :groups, :default_leaderboard_min_sessions, :integer, null: false, default: 3
  end
end
