class ToggleableFilters < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :custom_filters, :is_enabled, :boolean, null: false, default: true
    }
  end
end
