class AddRejectRepliesToStatuses < ActiveRecord::Migration[5.2]
  def change
    add_column :statuses, :reject_replies, :boolean
  end
end
