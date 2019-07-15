class CreateChatAccounts < ActiveRecord::Migration[5.2]
  def change
    create_table :chat_accounts do |t|
      t.references :account, foreign_key: { on_delete: :cascade }, null: false
      t.references :tag, foreign_key: { on_delete: :cascade }, null: false
      t.index [:account_id, :tag_id], unique: true
      t.index [:tag_id, :account_id]
      t.timestamps
    end
  end
end
