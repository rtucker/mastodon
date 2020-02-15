class SetDefaultUnhiddenOnStatuses < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      change_column_default :statuses, :hidden, false
      Status.in_batches.update_all(hidden: false)
    end
  end
end
