class AddHideBoostsToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :hide_boosts, :boolean
  end
end
