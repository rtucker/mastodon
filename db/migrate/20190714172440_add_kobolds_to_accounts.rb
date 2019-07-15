class AddKoboldsToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :accounts, :gently, :boolean, null: false, default: false }
    safety_assured { add_column :accounts, :kobold, :boolean, null: false, default: false }
  end
end
