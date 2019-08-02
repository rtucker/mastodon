class AddThreadToCustomFilters < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :custom_filters, :thread, :boolean, null: false, default: false }
  end
end
