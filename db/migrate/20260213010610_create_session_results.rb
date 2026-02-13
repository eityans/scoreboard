class CreateSessionResults < ActiveRecord::Migration[8.1]
  def change
    create_table :session_results do |t|
      t.references :poker_session, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :amount, null: false

      t.timestamps
    end

    add_index :session_results, [ :poker_session_id, :player_id ], unique: true
  end
end
