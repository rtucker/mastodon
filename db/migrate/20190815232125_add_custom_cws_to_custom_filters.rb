class AddCustomCwsToCustomFilters < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :custom_filters, :custom_cw, :text
      add_column :custom_filters, :override_cw, :boolean, null: false, default: false
    }
  end
end
