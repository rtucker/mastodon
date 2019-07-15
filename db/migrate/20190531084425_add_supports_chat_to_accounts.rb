class AddSupportsChatToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :accounts, :supports_chat, :boolean, null: false, default: false }
  end
end
