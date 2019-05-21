class AddOriginToStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def change
    add_column :statuses, :origin, :string
    add_index :statuses, :origin, unique: true, algorithm: :concurrently
  end
end
