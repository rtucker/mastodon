class MigrateUserKoboldsToAccount < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def up
    Account.local.find_each do |account|
      account.kobold = a.user_is_a_kobold? || false
      account.gently = a.user_gentlies_kobolds? || false
      account.save
    end
  end
end
