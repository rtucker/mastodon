class AddAdultsOnlyToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :accounts, :adults_only, :boolean, null: false, default: false }
  end
end
