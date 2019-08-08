class AddKnownToAccounts < ActiveRecord::Migration[5.2]
  def change
    add_column :accounts, :known, :boolean, null: false, default: false
  end
end
