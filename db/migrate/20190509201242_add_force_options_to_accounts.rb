class AddForceOptionsToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :accounts, :force_unlisted, :boolean, null: false, default: false
      add_column :accounts, :force_sensitive, :boolean, null: false, default: false
    }
  end
end
