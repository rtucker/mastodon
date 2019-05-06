class AddUnlistedToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :accounts, :unlisted, :boolean, null: false, default: false }
  end
end
