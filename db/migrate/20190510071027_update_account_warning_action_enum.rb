class UpdateAccountWarningActionEnum < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    AccountWarning.where(action: :force_unlisted).each do |warning|
      warning.severity = :suspend
      warning.save
    end

    AccountWarning.where(action: :force_sensitive).each do |warning|
      warning.severity = :silence
      warning.save
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
