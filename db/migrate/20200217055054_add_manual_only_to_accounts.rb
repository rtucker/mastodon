class AddManualOnlyToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column(:accounts, :manual_only, :boolean, default: false, null: false) }
  end
end
