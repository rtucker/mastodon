class RemoveProtocolFromAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured { remove_column :accounts, :protocol }
  end
end
