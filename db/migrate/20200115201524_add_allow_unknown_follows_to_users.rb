class AddAllowUnknownFollowsToUsers < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :users, :allow_unknown_follows, :boolean, null: false, default: false
    }
  end
end
