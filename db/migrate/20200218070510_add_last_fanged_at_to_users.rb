class AddLastFangedAtToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :last_fanged_at, :datetime
  end
end
