class DropSubscriptions < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      drop_table :subscriptions
    }
  end
end
