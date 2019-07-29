class AddBoostableToStatuses < ActiveRecord::Migration[5.2]
  def change
    add_column :statuses, :boostable, :boolean
  end
end
