class AddDiscardedAtToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :discarded_at, :datetime
  end
end
