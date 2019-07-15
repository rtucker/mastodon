class AddChatToTags < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def change
    safety_assured {
      add_column :tags, :chat, :boolean, default: false, null: false
      add_index :tags, :chat, where: :chat, algorithm: :concurrently
    }
  end
end
