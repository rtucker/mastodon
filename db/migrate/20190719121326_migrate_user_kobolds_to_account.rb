class MigrateUserKoboldsToAccount < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def up
    Account.local.find_each do |account|
      next if account.user.nil?
      account.kobold = account.user.settings.is_a_kobold? || false
      account.gently = account.user.settings.gentlies_kobolds? || false
      account.save
    end
  end
end
