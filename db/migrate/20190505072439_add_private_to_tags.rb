class AddPrivateToTags < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :tags, :local, :boolean, default: false, null: false
      add_column :tags, :private, :boolean, default: false, null: false
    }
  end
end
