class RemoveChat < ActiveRecord::Migration[5.2]
  def up
    Status.where(visibility: 6).find_each &:destroy
    remove_index :statuses, name: "index_statuses_on_account_id_and_id_and_visibility"
    safety_assured {
      remove_column :accounts, :supports_chat
      remove_column :tags, :chat
      drop_table :chat_accounts
    }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
