class AddNetworkIndexToStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def change
    add_index :statuses, :network, where: :network, algorithm: :concurrently
  end
end
