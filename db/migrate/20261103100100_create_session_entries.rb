class CreateSessionEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :session_entries do |t|
      t.references :poker_session, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.decimal :amount, precision: 12, scale: 1, null: false
      t.timestamps
    end
  end
end
