class AddPublicIndexToStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def change
    add_index :statuses, [:account_id, :id, :visibility], where: 'visibility IN (0, 1, 2, 4)', order: { id: :desc }, algorithm: :concurrently
  end
end
