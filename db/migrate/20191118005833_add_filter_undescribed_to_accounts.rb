class AddFilterUndescribedToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :accounts, :filter_undescribed, :boolean, default: false, null: false
    }
  end
end
