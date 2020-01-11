class AddFilterUndescribedToUsers < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :users, :filter_undescribed, :boolean, null: false, default: false
    }
  end
end
