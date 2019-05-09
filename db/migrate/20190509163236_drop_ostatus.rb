class DropOStatus < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      remove_column :accounts, :salmon_url
      remove_column :accounts, :hub_url
      remove_column :accounts, :subscription_expires_at
    }
  end
end
