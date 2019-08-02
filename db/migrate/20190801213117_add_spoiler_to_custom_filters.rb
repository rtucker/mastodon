class AddSpoilerToCustomFilters < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :custom_filters, :spoiler, :boolean, null: false, default: false }
  end
end
