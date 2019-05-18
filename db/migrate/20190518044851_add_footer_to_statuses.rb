class AddFooterToStatuses < ActiveRecord::Migration[5.2]
  def change
    add_column :statuses, :footer, :text
  end
end
