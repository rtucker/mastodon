class MigrateHiddenToHideProfile < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def up
    Account.local.find_each do |account|
      next unless account&.user
      account.user.settings.hide_public_profile = account.hidden || false
      account.hidden = false
    end
  end
end
