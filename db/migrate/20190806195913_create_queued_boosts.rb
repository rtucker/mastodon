class CreateQueuedBoosts < ActiveRecord::Migration[5.2]
  def change
    create_table :queued_boosts do |t|
      t.references :account, foreign_key: { on_delete: :cascade }
      t.references :status, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    add_index :queued_boosts, [:account_id, :status_id], unique: true
  end
end
