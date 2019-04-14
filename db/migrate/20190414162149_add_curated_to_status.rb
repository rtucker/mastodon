class AddCuratedToStatus < ActiveRecord::Migration[5.2]
  def change
    add_column :statuses, :curated, :boolean, null: true, default: nil
  end
end
