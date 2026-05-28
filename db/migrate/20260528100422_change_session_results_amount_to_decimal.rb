class ChangeSessionResultsAmountToDecimal < ActiveRecord::Migration[8.1]
  def up
    change_column :session_results, :amount, :decimal, precision: 12, scale: 1
  end

  def down
    change_column :session_results, :amount, :integer
  end
end
