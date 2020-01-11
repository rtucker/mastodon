class AddFiltersEnabledToUsers < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :users, :filters_enabled, :boolean, null: false, default: false
    end
  end
end
