class AddBlockAnonToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :accounts, :block_anon, :boolean, null: false, default: false
    }
  end
end
