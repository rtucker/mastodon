class AddHiddenToStatuses < ActiveRecord::Migration[5.2]
  def change
    add_column :statuses, :hidden, :boolean, default: false
  end
end
