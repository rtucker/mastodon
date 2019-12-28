class AddNormalizedTextToStatuses < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :statuses, :normalized_text, :text, null: false, default: ''
    }
  end
end
