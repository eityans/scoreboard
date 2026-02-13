class AddUniqueIndexToPlayersDisplayNameWithinGroup < ActiveRecord::Migration[8.1]
  def up
    duplicates = execute(<<~SQL)
      SELECT id FROM players
      WHERE id NOT IN (
        SELECT MIN(id) FROM players GROUP BY group_id, display_name
      )
    SQL

    if duplicates.any?
      execute("DELETE FROM session_results WHERE player_id IN (#{duplicates.map { |r| r["id"] }.join(",")})")
      execute("DELETE FROM players WHERE id IN (#{duplicates.map { |r| r["id"] }.join(",")})")
    end

    add_index :players, [ :group_id, :display_name ], unique: true
  end

  def down
    remove_index :players, [ :group_id, :display_name ]
  end
end
