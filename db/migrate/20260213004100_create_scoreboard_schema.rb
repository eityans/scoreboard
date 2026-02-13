class CreateScoreboardSchema < ActiveRecord::Migration[8.1]
  def up
    execute "CREATE SCHEMA IF NOT EXISTS scoreboard"
  end

  def down
    execute "DROP SCHEMA IF EXISTS scoreboard CASCADE"
  end
end
