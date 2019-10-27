class AddForcePrivateToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :accounts, :force_private, :boolean, null: false, default: false
    }
  end
end
