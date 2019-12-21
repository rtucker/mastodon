class AddFilterTimelinesOnlyToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :filter_timelines_only, :boolean, default: false, null: false
  end
end
