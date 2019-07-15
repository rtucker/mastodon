class AddUnlistedToTags < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def change
    safety_assured {
      add_column :tags, :unlisted, :boolean, default: false, null: false
      add_index :tags, :unlisted, where: :unlisted, algorithm: :concurrently
    }
  end
end
