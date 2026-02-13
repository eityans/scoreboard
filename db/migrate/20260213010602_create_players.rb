class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.references :group, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :display_name, null: false

      t.timestamps
    end

    add_index :players, [ :group_id, :user_id ], unique: true, where: "user_id IS NOT NULL"
  end
end
