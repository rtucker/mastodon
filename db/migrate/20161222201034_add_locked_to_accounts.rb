class AddLockedToAccounts < ActiveRecord::Migration[5.0]
  def change
    safety_assured {
      add_column :accounts, :locked, :boolean, null: false, default: false
    }
  end
end
