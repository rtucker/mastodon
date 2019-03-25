class AddHiddenToAccounts < ActiveRecord::Migration[5.2]
  def change
    add_column :accounts, :hidden, :boolean
  end
end
