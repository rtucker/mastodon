class AddNormalizedTextToStatuses < ActiveRecord::Migration[5.2]
  def change
    add_column :statuses, :normalized_text, :text, null: false, default: ''
  end
end
