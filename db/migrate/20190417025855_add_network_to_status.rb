class AddNetworkToStatus < ActiveRecord::Migration[5.2]
  def change
    add_column :statuses, :network, :boolean
  end
end
