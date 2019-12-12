class CreateConversationKicks < ActiveRecord::Migration[5.2]
  def change
    create_table :conversation_kicks do |t|
      t.references :account, null: false, foreign_key: {on_delete: :cascade}
      t.references :conversation, null: false, foreign_key: {on_delete: :cascade}
    end

    add_index :conversation_kicks, [:account_id, :conversation_id], unique: true
  end
end
