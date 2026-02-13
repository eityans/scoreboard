class CreatePokerSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :poker_sessions do |t|
      t.references :group, null: false, foreign_key: true
      t.date :played_on, null: false
      t.text :note
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :poker_sessions, [ :group_id, :played_on ]
  end
end
