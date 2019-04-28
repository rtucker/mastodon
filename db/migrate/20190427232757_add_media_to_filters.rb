class AddMediaToFilters < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :custom_filters, :exclude_media, :boolean, default: false, null: false
      add_column :custom_filters, :media_only, :boolean, default: false, null: false
    }
  end
end
