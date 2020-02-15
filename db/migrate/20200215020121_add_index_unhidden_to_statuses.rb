class AddIndexUnhiddenToStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_index :statuses, [:account_id, :id, :visibility], where: 'NOT hidden', algorithm: :concurrently, name: 'index_statuses_on_account_id_and_id_and_visibility_not_hidden'
  end
end
