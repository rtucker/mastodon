class AddInvertFiltersToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :invert_filters, :boolean, null: false, default: false
  end
end
