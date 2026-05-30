class AddAmountUnitToGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :groups, :amount_unit, :string, null: false, default: "point"
  end
end
