class AddEditedToStatuses < ActiveRecord::Migration[5.2]
  def change
    add_column :statuses, :edited, :boolean
  end
end
