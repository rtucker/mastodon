class AddFilterUndescribedToAccounts < ActiveRecord::Migration[5.2]
  def change
    add_column :accounts, :filter_undescribed, :boolean, default: false, null: false
  end
end
