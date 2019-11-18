class RemoveContextFromCustomFilters < ActiveRecord::Migration[5.2]
  def change
    safety_assured { remove_column :custom_filters, :context }
  end
end
