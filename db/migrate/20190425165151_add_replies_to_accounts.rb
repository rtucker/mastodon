class AddRepliesToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :accounts, :replies, :boolean, default: true, null: false }
  end
end
