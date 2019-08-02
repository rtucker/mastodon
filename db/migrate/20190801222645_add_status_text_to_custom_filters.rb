class AddStatusTextToCustomFilters < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :custom_filters, :status_text, :boolean, null: false, default: false }
  end
end
