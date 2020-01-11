class MigrateFilterUndescribedFromAccounts < ActiveRecord::Migration[5.2]
  def up
    Account.local.find_each do |account|
      account.user.update!(filter_undescribed: account.filter_undescribed)
    end
    safety_assured {
      remove_column :accounts, :filter_undescribed
    }
  end

  def down
    return true
    safety_assured {
      add_column :accounts, :filter_undescribed, :boolean, null: true, default: false
    }
  end
end
