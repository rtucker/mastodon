class AddFrozeToAccounts < ActiveRecord::Migration[5.2]
  def change
    add_column :accounts, :froze, :boolean
  end
end
