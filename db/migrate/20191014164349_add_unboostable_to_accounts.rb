class AddUnboostableToAccounts < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :accounts, :unboostable, :boolean, null: false, default: false
    }
  end
end
