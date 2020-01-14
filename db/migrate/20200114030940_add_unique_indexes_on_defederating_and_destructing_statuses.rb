class AddUniqueIndexesOnDefederatingAndDestructingStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    remove_index :destructing_statuses, :status_id
    remove_index :defederating_statuses, :status_id

    add_index :destructing_statuses, :status_id, unique: true, algorithm: :concurrently
    add_index :defederating_statuses, :status_id, unique: true, algorithm: :concurrently
  end
end
